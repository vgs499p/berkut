#!/bin/sh
# Assemble the Burrow IPA: the unsigned Release app, the Arch Linux
# ARM KDE image as a bundle resource, ad-hoc signed with the app's
# entitlements so a re-signing sideloader (Plume Impactor) carries them over.
set -eu
B=${BURROW_BUILD_ROOT:-/Volumes/BurrowBuild}
APP=$B/DerivedData/Build/Products/Release-iphoneos/Kernarium.app
IMG=${BURROW_IMAGE:-$B/arch/out/archlinuxarm-kde.erofs}
ENT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)/Burrow.entitlements
OUT=${1:?output ipa path}
W=$B/ipa
rm -rf "$W"; mkdir -p "$W/Payload"
ditto "$APP" "$W/Payload/Kernarium.app"
cp "$IMG" "$W/Payload/Kernarium.app/archlinuxarm-kde.erofs"
# Frameworks first, then the app with its entitlements.
for f in "$W"/Payload/Kernarium.app/Frameworks/*.framework; do
	codesign -f -s - "$f"
done
codesign -f -s - --entitlements "$ENT" "$W/Payload/Kernarium.app"
codesign -d --entitlements - "$W/Payload/Kernarium.app" 2>/dev/null | grep -c kernel || true
codesign --verify --deep "$W/Payload/Kernarium.app"
cd "$W" && rm -f "$OUT" && zip -qr -1 "$OUT" Payload
ls -la "$OUT"
