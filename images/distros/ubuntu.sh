# Ubuntu 26.04 LTS, from the ubuntu-base tarball.
DESKTOPS="phosh lomiri plasma"
SUITE=resolute

fetch_base() {
	local url=https://cdimage.ubuntu.com/ubuntu-base/releases/26.04/release file
	curl -fL --retry 3 -o "$W/SHA256SUMS" "$url/SHA256SUMS"
	file=$(awk '/base-arm64\.tar\.gz$/ {sub(/^\*/, "", $2); print $2}' "$W/SHA256SUMS" | sort -V | tail -1)
	curl -fL --retry 3 -o "$W/$file" "$url/$file"
	(cd "$W" && grep -F "$file" SHA256SUMS | sha256sum -c -)
	bsdtar -xpf "$W/$file" -C "$R"
}

install_packages() {
	export DEBIAN_FRONTEND=noninteractive
	rm -f /etc/apt/sources.list /etc/apt/sources.list.d/*
	cat > /etc/apt/sources.list.d/ubuntu.sources <<-SOURCES
	Types: deb
	URIs: http://ports.ubuntu.com/ubuntu-ports
	Suites: resolute resolute-updates resolute-security
	Components: main universe
	Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
	SOURCES
	apt-get update
	apt-get -y dist-upgrade
	local pkgs="systemd-sysv udev dbus-user-session libpam-systemd systemd-resolved sudo nano htop
		locales sddm weston network-manager upower pipewire pipewire-pulse wireplumber
		libgl1-mesa-dri libegl-mesa0 mesa-vulkan-drivers fonts-noto-core fonts-noto-color-emoji
		fonts-dejavu-core"
	case $DE in
	phosh) pkgs+=" phosh phoc squeekboard gnome-console nautilus gnome-control-center" ;;
	lomiri) pkgs+=" lomiri lomiri-desktop-session lomiri-terminal-app" ;;
	plasma) pkgs+=" kde-plasma-desktop plasma-nm plasma-pa" ;;
	esac
	# Recommends carry the parts of a desktop session that are not hard
	# dependencies.
	apt-get -y install $pkgs
	locale-gen en_US.UTF-8
}

clean_packages() {
	apt-get clean
	rm -rf /var/lib/apt/lists/*
}
