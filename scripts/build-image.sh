#!/bin/sh
# Builds the Arch Linux ARM + Plasma Mobile erofs image in an arm64 container.
set -eu
REPO=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
B=${BERKUT_BUILD_ROOT:-/Volumes/BerkutBuild}
mkdir -p "$B/arch/out"
cp "$REPO/image/build-arch-image.sh" "$B/arch/"
[ -f "$B/arch/ArchLinuxARM-aarch64-latest.tar.gz" ] ||
	curl -fL -o "$B/arch/ArchLinuxARM-aarch64-latest.tar.gz" \
		http://fl.us.mirror.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz
container run --rm --arch arm64 -c 4 -m 8G --cap-add ALL \
	-v "$B/arch:/in" -v "$B/arch/out:/out" docker.io/library/alpine:3.22 \
	sh /in/build-arch-image.sh
