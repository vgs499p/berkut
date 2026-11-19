#!/bin/sh
# Creates the case-sensitive build volume, clones upstream Kernarium at the
# pinned commit and applies the Berkut patches on a `berkut` branch.
# Usage: scripts/setup.sh [sparsebundle path]   (BERKUT_BUILD_ROOT to override)
set -eu
REPO=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
. "$REPO/upstream.env"
B=${BERKUT_BUILD_ROOT:-/Volumes/BerkutBuild}
IMAGE=${1:-$HOME/BerkutBuild.sparsebundle}
if [ ! -d "$B" ]; then
	[ -e "$IMAGE" ] || hdiutil create -size 120g -type SPARSEBUNDLE \
		-fs "Case-sensitive APFS" -volname BerkutBuild "$IMAGE"
	hdiutil attach "$IMAGE" -nobrowse -mountpoint "$B"
fi
if [ ! -d "$B/Kernarium" ]; then
	git clone "$UPSTREAM_URL" "$B/Kernarium"
	git -C "$B/Kernarium" switch -c berkut "$UPSTREAM_COMMIT"
	git -C "$B/Kernarium" am "$REPO"/patches/*.patch
fi
printf 'UML_KERNEL_SOURCE_DIR=%s/linux\n' "$B" > "$B/Kernarium/kernel/mainline-6.18/source-location.conf"
mkdir -p "$B/arch/out" "$B/bootbase"
cp "$REPO/image/build-arch-image.sh" "$B/arch/"
echo "Build root ready: $B"
