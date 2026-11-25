#!/bin/bash
# Publishes built images to the images-1 pre-release and rewrites its
# catalog.json, keeping entries for images this run did not rebuild.
#   images/publish.sh <directory of image parts and manifests>
set -euo pipefail
DIR=$1 TAG=images-1
shopt -s nullglob
manifests=("$DIR"/*.json)
[ ${#manifests[@]} -gt 0 ] || { echo "nothing built"; exit 0; }

gh release view "$TAG" >/dev/null 2>&1 || gh release create "$TAG" --prerelease --latest=false \
	--target "${GITHUB_SHA:-main}" --title "Guest images (experimental)" \
	--notes "Systems Berkut's installer downloads. Experimental: not all are tested on a device."
gh release upload "$TAG" "$DIR"/*.erofs.zst.* --clobber

old=$(mktemp -d)
gh release download "$TAG" --pattern catalog.json --dir "$old" 2>/dev/null || true
python3 - "$old/catalog.json" "$DIR" "${manifests[@]}" <<'PY'
import json, os, sys
old, directory, *manifests = sys.argv[1:]
images = {}
if os.path.exists(old):
    images = {i["file"]: i for i in json.load(open(old))["images"]}
for path in manifests:
    if os.path.basename(path) != "catalog.json":
        entry = json.load(open(path))
        images[entry["file"]] = entry
json.dump({"images": [images[k] for k in sorted(images)]},
          open(os.path.join(directory, "catalog.json"), "w"), indent=1)
PY
# The catalog goes last, so it never names a part that is not there yet.
gh release upload "$TAG" "$DIR/catalog.json" --clobber
