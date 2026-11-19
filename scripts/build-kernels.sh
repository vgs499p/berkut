#!/bin/sh
# Builds and publishes the Linux and Android UML kernels with Homebrew LLVM
# (Apple clang lacks Linux 6.18's __counted_by support).
set -eu
B=${BURROW_BUILD_ROOT:-/Volumes/BurrowBuild}
export UML_KERNEL_CC=/opt/homebrew/opt/llvm/bin/clang UML_KERNEL_LD=/opt/homebrew/opt/lld/bin/ld.lld
cd $B/Kernarium
L=.build/logs
OUT=$B/Kernarium/.build/kernel/artifacts
OBJ=/opt/homebrew/opt/llvm/bin/llvm-objcopy
mkdir -p $L
dependencies/prepare.sh --product kernel-host-tools > $L/prepare-kernel.log 2>&1
dependencies/prepare.sh --archive-manifest dependencies/kernel-host-tools/archives.tsv \
	--cache .build/dependency-cache >> $L/prepare-kernel.log 2>&1
dependencies/build-kernel-host-tools.sh > $L/hosttools.log 2>&1
kernel/mainline-6.18/scripts/prepare-source.sh > $L/kernel-prepare.log 2>&1
kernel/mainline-6.18/build/build-kernel.sh --slice arm64 --build $B/build-arm64 > $L/kernel.log 2>&1
echo kernel-ok
kernel/mainline-6.18/build/publish-artifact.py --source $B/linux \
	--build $B/build-arm64 --output-root "$OUT" \
	--release-id 20261119-6.18.60-ca2 --objcopy "$OBJ" > $L/kpublish.log 2>&1
echo publish-ok
kernel/mainline-6.18/build/build-kernel.sh --product android --build $B/build-android > $L/kernel-android.log 2>&1
echo android-kernel-ok
kernel/mainline-6.18/build/publish-artifact.py --source $B/linux \
	--build $B/build-android --product android --output-root "$OUT" \
	--release-id 20261119-6.18.60-ca1 --objcopy "$OBJ" > $L/kpublish-android.log 2>&1
echo android-publish-ok
ls "$OUT"
# The release string carries the local replay's commit, which differs per
# checkout: point the accepted descriptors at what was just built.
for pair in "mainline-6.18:accepted-4k.env:ca2" "android-6.18:accepted-android-4k.env:ca1"; do
	family=${pair%%:*} rest=${pair#*:} env=kernel/mainline-6.18/artifacts/${rest%%:*}
	id=20261119-6.18.60-${rest##*:}
	release=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['release'])" \
		"$OUT/$family-arm64-4k-$id/kernel-artifact.json")
	sed -i '' "s/^UML_KERNEL_ARTIFACT_RELEASE=.*/UML_KERNEL_ARTIFACT_RELEASE='$release'/" "$env"
	echo "$env -> $release"
done
