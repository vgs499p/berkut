# Fedora, installed into an empty root by the official container's dnf.
DESKTOPS="plasma-mobile phosh plasma xfce"

fetch_base() {
	local pkgs="fedora-release filesystem bash coreutils systemd systemd-udev systemd-resolved
		dbus-broker sudo passwd shadow-utils util-linux dnf nano htop fastfetch
		glibc-langpack-en sddm weston NetworkManager upower pipewire pipewire-pulseaudio
		wireplumber mesa-dri-drivers mesa-vulkan-drivers google-noto-sans-fonts
		google-noto-color-emoji-fonts dejavu-sans-fonts"
	case $DE in
	plasma-mobile) pkgs+=" plasma-mobile plasma-desktop plasma-workspace kwin plasma-nm plasma-pa konsole dolphin" ;;
	plasma) pkgs+=" plasma-desktop plasma-workspace kwin plasma-nm plasma-pa konsole dolphin kate" ;;
	phosh) pkgs+=" phosh phoc squeekboard gnome-console nautilus gnome-control-center" ;;
	xfce) pkgs+=" xfce4-session xfce4-panel xfwm4 xfdesktop xfce4-settings xfce4-terminal Thunar
		xorg-x11-server-Xorg xorg-x11-drv-libinput" ;;
	esac
	docker run --rm -v "$R:/r" registry.fedoraproject.org/fedora:latest \
		dnf -y --installroot=/r --use-host-config install $(echo $pkgs)
}

# fetch_base already installed everything.
install_packages() { :; }

clean_packages() {
	dnf clean all || true
	rm -rf /var/cache/libdnf5/* /var/cache/dnf/*
}
