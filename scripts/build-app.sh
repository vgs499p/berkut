#!/bin/sh
# Fetches and builds the iOS dependencies, the Linux and Android runtimes, the
# framework bundle and the unsigned Release application. Run after
# build-kernels.sh and build-boot-base.sh.
set -eu
B=${BURROW_BUILD_ROOT:-/Volumes/BurrowBuild}
K=$B/Kernarium
cd "$K"
L=.build/logs; mkdir -p $L
# Mesa's KosmicKrisp build needs mako, packaging and PyYAML.
[ -x "$B/venv/bin/python3" ] || { python3 -m venv "$B/venv" && "$B/venv/bin/pip" -q install mako packaging pyyaml; }
export PATH="$B/venv/bin:$PATH"
for p in kernel-host-tools ios-compression ios-storage ios-network apple-gpu-vulkan-experiment; do
	dependencies/prepare.sh --product $p >> $L/prepare.log 2>&1
done
dependencies/build-ios-zstd.sh > $L/zstd.log 2>&1
dependencies/build-ios-storage.sh > $L/storage.log 2>&1
dependencies/build-ios-network.sh --platform ios > $L/network.log 2>&1
dependencies/build-apple-gpu.sh --platform ios > $L/gpu.log 2>&1
for preset in kernarium-ios-device kernarium-ios-device-android; do
	cmake --preset $preset > $L/cfg-$preset.log 2>&1
	cmake --build --preset $preset > $L/build-$preset.log 2>&1
done
Kernarium/scripts/package-ios-frameworks.sh --sdk device > $L/package.log 2>&1
cd Kernarium
xcodebuild -project Kernarium.xcodeproj -scheme Kernarium -configuration Release \
	-sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath "$B/DerivedData" \
	CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build \
	> ../$L/xcodebuild.log 2>&1
echo "App: $B/DerivedData/Build/Products/Release-iphoneos/Kernarium.app"
