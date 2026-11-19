#!/bin/sh
# Builds the static BusyBox/e2fsprogs boot base in an arm64 container, installs
# it where the runtime build expects it and records its size and digest in the
# accepted descriptor, then runs upstream's verifier.
set -eu
REPO=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
B=${BURROW_BUILD_ROOT:-/Volumes/BurrowBuild}
K=$B/Kernarium
cp "$REPO/bootbase/build-boot-base.sh" "$B/bootbase/make.sh"
container run --rm --arch arm64 -c 6 -v "$B/bootbase:/out" docker.io/library/alpine:3.22 sh /out/make.sh
D=$K/.build/rootfs/starter-20260928-boot-base-r1
mkdir -p "$D"
A=$D/uml-boot-base-aarch64.cpio.gz
cp "$B/bootbase/uml-boot-base-aarch64.cpio.gz" "$A"
size=$(stat -f %z "$A"); sha=$(shasum -a 256 "$A" | cut -d' ' -f1)
sed -i '' "s/^UML_BOOT_BASE_SIZE=.*/UML_BOOT_BASE_SIZE=$size/; s/^UML_BOOT_BASE_SHA256=.*/UML_BOOT_BASE_SHA256='$sha'/" \
	"$K/tools/rootfs/boot-ramdisk/accepted-aarch64.env"
python3 "$K/tools/rootfs/boot-ramdisk/verify_base.py" --architecture aarch64 --archive "$A"
