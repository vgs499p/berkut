#!/bin/sh
# Applies the Burrow name, bundle identifier and icon to a Kernarium checkout.
# Usage: apply-branding.sh /path/to/Kernarium-checkout
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$HERE/branding.env"
K=${1:?Kernarium checkout}
PLIST="$K/Kernarium/Info.plist"
PBX="$K/Kernarium/Kernarium.xcodeproj/project.pbxproj"
ICONS="$K/Kernarium/Kernarium/Assets.xcassets/AppIcon.appiconset"

/usr/libexec/PlistBuddy -c "Delete :CFBundleDisplayName" "$PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string $BURROW_NAME" "$PLIST"
mic=$(/usr/libexec/PlistBuddy -c "Print :NSMicrophoneUsageDescription" "$PLIST")
/usr/libexec/PlistBuddy -c "Set :NSMicrophoneUsageDescription $BURROW_NAME ${mic#Kernarium }" "$PLIST"
# Only the application target's identifier; the test targets keep theirs.
sed -i '' "s/PRODUCT_BUNDLE_IDENTIFIER = com.imxieyi.Kernarium;/PRODUCT_BUNDLE_IDENTIFIER = $BURROW_BUNDLE_ID;/" "$PBX"

cp "$HERE/AppIcon.png" "$HERE/AppIcon-dark.png" "$HERE/AppIcon-tinted.png" "$ICONS/"
python3 - "$ICONS/Contents.json" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
for image in d["images"]:
    if image.get("platform") != "ios":
        continue
    look = {a["value"] for a in image.get("appearances", [])}
    image["filename"] = ("AppIcon-dark.png" if "dark" in look else
                         "AppIcon-tinted.png" if "tinted" in look else
                         "AppIcon.png")
json.dump(d, open(p, "w"), indent=2)
open(p, "a").write("\n")
PY
echo "Applied $BURROW_NAME ($BURROW_BUNDLE_ID) to $K"
