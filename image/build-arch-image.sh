#!/bin/sh
# Builds an Arch Linux ARM + KDE Plasma erofs image for Kernarium.
# Runs as root inside an arm64 Alpine container with /in (ALARM tarball, this
# script) and /out mounted. The root is assembled on the container's own disk
# so ownership, xattrs and device nodes survive.
set -eux

apk add --no-cache erofs-utils tar zstd xz util-linux libarchive-tools >/dev/null

R=/build/root
rm -rf /build; mkdir -p "$R"
bsdtar -xpf /in/ArchLinuxARM-aarch64-latest.tar.gz -C "$R" 2>/dev/null ||
	tar -xpzf /in/ArchLinuxARM-aarch64-latest.tar.gz -C "$R"

mount --bind "$R" "$R"
mount -t proc proc "$R/proc"
mount -t sysfs sys "$R/sys"
mount --rbind /dev "$R/dev"
mount -t tmpfs tmpfs "$R/run"
mount -t tmpfs tmpfs "$R/tmp"
rm -f "$R/etc/resolv.conf"
cp /etc/resolv.conf "$R/etc/resolv.conf"

cat > "$R/root/inside.sh" <<'INSIDE'
set -eux
sed -i 's/^CheckSpace/#CheckSpace/; s/^#ParallelDownloads.*/ParallelDownloads = 8/; s/^\[options\]/[options]\nDisableDownloadTimeout/' /etc/pacman.conf
printf 'Server = http://%s.mirror.archlinuxarm.org/$arch/$repo\n' fl.us nj.us ca.us de dk > /etc/pacman.d/mirrorlist
pacman-key --init
pacman-key --populate archlinuxarm
# The guest is a UML kernel; drop the board kernel, firmware and initramfs tooling.
pacman -Rdd --noconfirm linux-aarch64 linux-firmware mkinitcpio || true
pacman -Syu --noconfirm
pacman -S --noconfirm --needed \
	plasma-desktop plasma-workspace kwin sddm sddm-kcm breeze breeze-gtk \
	kscreen plasma-pa plasma-systemmonitor kinfocenter powerdevil \
	xdg-desktop-portal-kde systemsettings konsole dolphin kate ark spectacle \
	gwenview okular plasma-nm networkmanager-qt \
	mesa vulkan-virtio vulkan-tools mesa-utils \
	pipewire pipewire-pulse wireplumber \
	noto-fonts noto-fonts-emoji ttf-dejavu \
	firefox sudo nano htop fastfetch xorg-xwayland \
	networkmanager upower
# Plasma Mobile as an alternate session, when the repository carries it.
pacman -S --noconfirm --needed plasma-mobile
test -f /usr/share/wayland-sessions/plasma-mobile.desktop
systemctl enable sddm.service

# Accounts: uml/uml (sudo via wheel), root/root as in stock Arch Linux ARM.
id uml >/dev/null 2>&1 || useradd -m -G wheel,video,render,input,audio -s /bin/bash uml
echo 'uml:uml' | chpasswd
echo 'root:root' | chpasswd
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/10-wheel
chmod 0440 /etc/sudoers.d/10-wheel
echo burrow > /etc/hostname

# Same desktop policy as tools/rootfs/desktop/setup/kde.
systemctl mask getty@tty0.service getty@tty1.service
for d in Desktop Documents Downloads Music Pictures Public Templates Videos \
	.config .local .local/share .local/share/Trash .local/share/Trash/files \
	.local/share/Trash/info .local/share/pki .local/share/sddm; do
	install -d -m 0755 -o uml -g uml "/home/uml/$d"
done
rm -f /usr/share/vulkan/icd.d/lvp_icd.*.json /usr/share/vulkan/icd.d/lvp_icd.json
f=/usr/share/plasma/plasmoids/org.kde.desktopcontainment/contents/config/main.xml
[ -f "$f" ] && sed -i 's#<default>desktop:/</default>#<default>file:///home/uml/Desktop</default>#' "$f"
install -d -m 0755 /etc/sddm.conf.d
printf '%s\n' '[Autologin]' 'User=uml' 'Session=plasma-mobile' 'Relogin=false' \
	> /etc/sddm.conf.d/uml-autologin.conf
# The image has Xwayland but no X server, so SDDM's greeter runs on KWin.
printf '%s\n' '[General]' 'DisplayServer=wayland' \
	'GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell' '' \
	'[Wayland]' \
	'CompositorCommand=kwin_wayland --drm --no-lockscreen --no-global-shortcuts --locale1' \
	> /etc/sddm.conf.d/10-wayland.conf
# Classify the Kernarium input devices, as the postmarketOS setup does, so
# libinput and KWin treat them as a touchscreen and a keyboard.
install -d -m 0755 /etc/udev/rules.d
cat > /etc/udev/rules.d/59-kernarium-input.rules <<'RULES'
ACTION=="add|change", SUBSYSTEM=="input", KERNEL=="event*", ATTRS{name}=="Kernarium Touchscreen", ENV{ID_INPUT}="1", ENV{ID_INPUT_TOUCHSCREEN}="1"
ACTION=="add|change", SUBSYSTEM=="input", KERNEL=="event*", ATTRS{name}=="Kernarium Keyboard", ENV{ID_INPUT}="1", ENV{ID_INPUT_KEYBOARD}="1"
RULES
# Interpreter-friendly Plasma defaults for uml: no animations, blur or
# translucency, no file indexer, no session restore or splash screen.
cat > /home/uml/.config/kwinrc <<'CFG'
[Compositing]
AnimationSpeed=0
LatencyPolicy=Low

[Plugins]
blurEnabled=false
contrastEnabled=false
translucencyEnabled=false
slidingpopupsEnabled=false
scaleEnabled=false
fadingpopupsEnabled=false
CFG
cat > /home/uml/.config/kdeglobals <<'CFG'
[KDE]
AnimationDurationFactor=0
CFG
cat > /home/uml/.config/baloofilerc <<'CFG'
[Basic Settings]
Indexing-Enabled=false
CFG
cat > /home/uml/.config/ksmserverrc <<'CFG'
[General]
loginMode=emptySession
CFG
cat > /home/uml/.config/ksplashrc <<'CFG'
[KSplash]
Engine=none
Theme=None
CFG
chown uml:uml /home/uml/.config/kwinrc /home/uml/.config/kdeglobals \
	/home/uml/.config/baloofilerc /home/uml/.config/ksmserverrc /home/uml/.config/ksplashrc
# Plasma starts as systemd user services; under the interpreter they can miss
# systemd's start deadlines and KWin's watchdog, which ends the session.
install -d /etc/systemd/user.conf.d /etc/systemd/user/plasma-kwin_wayland.service.d
printf '%s\n' '[Manager]' 'DefaultTimeoutStartSec=infinity' \
	> /etc/systemd/user.conf.d/burrow.conf
printf '%s\n' '[Service]' 'WatchdogSec=0' 'TimeoutStartSec=infinity' \
	> /etc/systemd/user/plasma-kwin_wayland.service.d/burrow.conf
# burrow-logs: what ended the desktop session, for a screenshot from the console.
cat > /usr/local/bin/burrow-logs <<'SH'
#!/bin/sh
[ "$(id -u)" -eq 0 ] || { echo "burrow-logs needs root: su -  (password root)"; exit 1; }
u=$(id -u uml)
echo "== sessions"; loginctl list-sessions --no-legend
echo "== sddm"; journalctl -b --no-pager -o cat -u sddm | tail -n "${1:-15}"
echo "== failed user units"; systemctl --user -M uml@ --failed --no-legend 2>/dev/null
echo "== coredumps"; coredumpctl list --no-pager --no-legend 2>/dev/null | tail -5
echo "== wayland-session.log"; tail -n "${1:-15}" /home/uml/.local/share/sddm/wayland-session.log 2>/dev/null
echo "== uml journal (errors)"; journalctl -b --no-pager -o short-monotonic _UID="$u" -p warning | tail -n "${1:-15}"
SH
# burrow-session plasma|plasma-mobile: switch the autologin session and restart it.
cat > /usr/local/bin/burrow-session <<'SH'
#!/bin/sh
case "$1" in plasma|plasma-mobile) ;; *) echo "usage: burrow-session plasma|plasma-mobile"; exit 2 ;; esac
sed -i "s/^Session=.*/Session=$1/" /etc/sddm.conf.d/uml-autologin.conf
systemctl stop "user@$(id -u uml).service"
systemctl restart sddm
SH
chmod 0755 /usr/local/bin/burrow-logs /usr/local/bin/burrow-session
# Plasma and Qt expect a UTF-8 locale.
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo LANG=en_US.UTF-8 > /etc/locale.conf
printf '%s\n' '[Daemon]' 'Autolock=false' 'LockOnResume=false' 'Timeout=0' \
	> /home/uml/.config/kscreenlockerrc
chown uml:uml /home/uml/.config/kscreenlockerrc

# Network: NetworkManager, which Plasma's network indicator reads, in place of
# the systemd-networkd DHCP Arch Linux ARM's tarball ships; resolved stays the
# resolver. The SLiRP link appears as a wired connection.
systemctl disable systemd-networkd.service systemd-networkd.socket || true
systemctl enable NetworkManager.service systemd-resolved.service
systemctl set-default graphical.target

# Every guest makes its own machine ID at first boot.
: > /etc/machine-id
install -d /var/lib/dbus
ln -sfn /etc/machine-id /var/lib/dbus/machine-id

pacman -Scc --noconfirm
rm -rf /var/cache/pacman/pkg/* /var/log/journal/* /root/.cache
INSIDE

chroot "$R" /bin/bash /root/inside.sh
rm -f "$R/root/inside.sh"
ln -sfn /run/systemd/resolve/stub-resolv.conf "$R/etc/resolv.conf"

umount -l "$R/dev" "$R/proc" "$R/sys" "$R/run" "$R/tmp" || true
umount -l "$R" || true
du -sh "$R"
# Keep real modification times: SDDM ignores configuration files stamped at
# the epoch, which -T0 would do, and falls back to X11 without autologin.
mkfs.erofs -zlz4hc,12 -Eztailpacking \
	/out/archlinuxarm-kde.erofs.tmp "$R" ||
	mkfs.erofs -zlz4hc,12 /out/archlinuxarm-kde.erofs.tmp "$R"
mv /out/archlinuxarm-kde.erofs.tmp /out/archlinuxarm-kde.erofs
ls -la /out
