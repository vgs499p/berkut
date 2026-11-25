# Guest setup common to every distro and desktop. Sourced inside the image's
# root by build.sh, with DISTRO and DE set.
F=/root/berkut/files

case $DE in
xfce) session_dir=/usr/share/xsessions ;;
*) session_dir=/usr/share/wayland-sessions ;;
esac
# Fail the build rather than ship an image whose autologin cannot start.
test -f "$session_dir/$DE.desktop" || { ls /usr/share/wayland-sessions /usr/share/xsessions || true; exit 1; }

install -d /etc/berkut /etc/sddm.conf.d /etc/sudoers.d /etc/udev/rules.d
echo "$DE" > /etc/berkut/session
echo berkut > /etc/hostname
echo LANG=en_US.UTF-8 > /etc/locale.conf

# First boot creates the account (from the installer's choices when present).
install -m 0755 "$F/berkut-firstboot" "$F/berkut-logs" "$F/berkut-reset" /usr/local/bin/
install -m 0644 "$F/berkut-firstboot.service" /etc/systemd/system/
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/10-wheel
chmod 0440 /etc/sudoers.d/10-wheel
getent group wheel >/dev/null || groupadd -r wheel

# SDDM on Wayland: the images have no X server except Xfce's. KWin draws the
# greeter where it is installed, SDDM's default (weston) elsewhere.
printf '%s\n' '[General]' 'DisplayServer=wayland' > /etc/sddm.conf.d/10-wayland.conf
if command -v kwin_wayland >/dev/null; then
	printf '%s\n' 'GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell' '' '[Wayland]' \
		'CompositorCommand=kwin_wayland --drm --no-lockscreen --no-global-shortcuts --locale1' \
		>> /etc/sddm.conf.d/10-wayland.conf
fi

install -m 0644 "$F/59-kernarium-input.rules" /etc/udev/rules.d/
rm -f /usr/share/vulkan/icd.d/lvp_icd*.json

# Ubuntu's NetworkManager leaves wired links alone unless netplan hands them
# over; the guest's only link is wired. An empty file of the same name masks it.
if [ -e /usr/lib/NetworkManager/conf.d/10-globally-managed-devices.conf ]; then
	install -d /etc/NetworkManager/conf.d
	: > /etc/NetworkManager/conf.d/10-globally-managed-devices.conf
fi

# Slow-machine defaults, copied into the home directory at first boot.
case $DE in
plasma|plasma-mobile)
	install -d /etc/skel/.config /etc/systemd/user.conf.d /etc/systemd/user/plasma-kwin_wayland.service.d
	cp "$F"/kde/* /etc/skel/.config/
	printf '%s\n' '[Manager]' 'DefaultTimeoutStartSec=infinity' > /etc/systemd/user.conf.d/berkut.conf
	printf '%s\n' '[Service]' 'WatchdogSec=0' 'TimeoutStartSec=infinity' \
		> /etc/systemd/user/plasma-kwin_wayland.service.d/berkut.conf
	;;
esac
install -d /etc/skel/.local/share/sddm

# The console is the serial line; gettys on the VTs can steal them from SDDM.
systemctl mask getty@tty0.service getty@tty1.service
systemctl disable systemd-networkd.service systemd-networkd.socket 2>/dev/null || true
# Ubuntu and Fedora ship display managers' alternatives; SDDM is the one.
# One at a time: systemctl gives up on the whole list if one unit is missing.
for unit in gdm.service gdm3.service lightdm.service greetd.service phosh.service; do
	systemctl disable "$unit" 2>/dev/null || true
done
# Debian and Ubuntu start only the display manager this file names, and a
# desktop's dependencies may have written another (Lomiri brings LightDM).
if [ "$DISTRO" = ubuntu ]; then
	install -d /etc/X11
	echo /usr/bin/sddm > /etc/X11/default-display-manager
fi
systemctl enable --force sddm.service
systemctl enable NetworkManager.service systemd-resolved.service berkut-firstboot.service
systemctl set-default graphical.target

# root/root, as in the Arch image.
echo 'root:root' | chpasswd

: > /etc/machine-id
install -d /var/lib/dbus
ln -sfn /etc/machine-id /var/lib/dbus/machine-id
rm -rf /var/log/journal/* /root/.cache
