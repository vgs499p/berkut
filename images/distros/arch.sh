# Arch Linux ARM.
DESKTOPS="plasma-mobile phosh plasma"

fetch_base() {
	local url=http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz
	curl -fL --retry 3 -o "$W/base.tar.gz" "$url"
	curl -fL --retry 3 -o "$W/base.tar.gz.sig" "$url.sig"
	# The Arch Linux ARM Build System signing key.
	export GNUPGHOME=$W/gnupg; mkdir -m 700 -p "$GNUPGHOME"
	gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys 68B3537F39A313B3E574D06777193F152BDBE6A6
	gpg --status-fd 1 --verify "$W/base.tar.gz.sig" "$W/base.tar.gz" |
		grep -q "VALIDSIG 68B3537F39A313B3E574D06777193F152BDBE6A6"
	bsdtar -xpf "$W/base.tar.gz" -C "$R"
	rm -f "$W/base.tar.gz"
}

install_packages() {
	sed -i 's/^CheckSpace/#CheckSpace/; s/^\[options\]/[options]\nDisableDownloadTimeout/' /etc/pacman.conf
	printf 'Server = http://%s.mirror.archlinuxarm.org/$arch/$repo\n' fl.us nj.us ca.us de dk > /etc/pacman.d/mirrorlist
	pacman-key --init
	pacman-key --populate archlinuxarm
	# The guest runs Berkut's UML kernel.
	pacman -Rdd --noconfirm linux-aarch64 linux-firmware mkinitcpio || true
	pacman -Syu --noconfirm
	local pkgs="sddm weston mesa vulkan-virtio networkmanager upower pipewire pipewire-pulse
		wireplumber noto-fonts noto-fonts-emoji ttf-dejavu sudo nano htop fastfetch"
	case $DE in
	plasma-mobile) pkgs+=" plasma-mobile plasma-desktop plasma-workspace kwin breeze plasma-nm plasma-pa powerdevil konsole dolphin" ;;
	plasma) pkgs+=" plasma-desktop plasma-workspace kwin breeze plasma-nm plasma-pa powerdevil konsole dolphin kate" ;;
	phosh) pkgs+=" phosh phoc squeekboard gnome-console nautilus gnome-control-center" ;;
	esac
	pacman -S --noconfirm --needed $pkgs
	sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
	locale-gen
	# The tarball's stock account.
	userdel -r alarm 2>/dev/null || true
}

clean_packages() {
	pacman -Scc --noconfirm
	rm -rf /var/cache/pacman/pkg/*
}
