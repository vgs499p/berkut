#!/bin/bash
# Builds one Berkut guest image. Runs as root on an arm64 Linux host (the
# GitHub Actions ubuntu-24.04-arm runner) with erofs-utils, zstd, bsdtar,
# gpg and, for Fedora, docker.
#   images/build.sh <arch|fedora|ubuntu> <plasma-mobile|phosh|plasma|xfce|lomiri> <outdir>
set -euxo pipefail
# A private mount namespace: the runner's mounts are shared, so binds made
# under the root would otherwise also appear beneath it and end up packed.
if [ -z "${BERKUT_NS:-}" ]; then
	exec env BERKUT_NS=1 unshare --mount --propagation private "$0" "$@"
fi
DISTRO=$1 DE=$2 OUT=$(mkdir -p "$3" && cd "$3" && pwd)
HERE=$(cd "$(dirname "$0")" && pwd)
W=${BERKUT_WORK:-/mnt/berkut-work}
R=$W/root
mkdir -p "$R"

cleanup() {
	# Anything the package manager left running (gpg-agent) holds the root.
	fuser -k -M -m "$R" 2>/dev/null || true
	umount -R -l "$R" 2>/dev/null || true
}
trap cleanup EXIT

# 1. A base root filesystem, verified where the distro publishes a signature.
. "$HERE/distros/$DISTRO.sh"
grep -qw "$DE" <<<"$DESKTOPS" || { echo "$DISTRO has no $DE image"; exit 1; }
fetch_base

# 2. Packages and guest setup inside the root.
mount --bind "$R" "$R"
mkdir -p "$R"/{dev,proc,sys,run,tmp}
mount --rbind /dev "$R/dev"
mount -t proc proc "$R/proc"
mount -t sysfs sys "$R/sys"
mount -t tmpfs tmpfs "$R/run"
mount -t tmpfs tmpfs "$R/tmp"
rm -f "$R/etc/resolv.conf"
cp /etc/resolv.conf "$R/etc/resolv.conf"

mkdir -p "$R/root/berkut"
cp -r "$HERE/files" "$HERE/guest-setup.sh" "$HERE/distros/$DISTRO.sh" "$R/root/berkut/"
chroot "$R" /usr/bin/env -i HOME=/root PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
	DISTRO="$DISTRO" DE="$DE" /bin/bash -euxc \
	". /root/berkut/$DISTRO.sh; install_packages; . /root/berkut/guest-setup.sh; clean_packages"
rm -rf "$R/root/berkut"
ln -sfn /run/systemd/resolve/stub-resolv.conf "$R/etc/resolv.conf"
umount -R -l "$R"
if findmnt -rn -o TARGET | grep -q "^$R"; then
	echo "mounts remain under $R"; findmnt -rn -o TARGET | grep "^$R"; exit 1
fi

# 3. Pack. Keep real file times: SDDM ignores configuration dated at the epoch.
NAME=$DISTRO-$DE
du -sh "$R"
mkfs.erofs -zlz4hc,12 -Eztailpacking "$W/$NAME.erofs" "$R" >/dev/null
rm -rf "$R"

# A release asset must stay under 2 GiB: compress and split.
size=$(stat -c %s "$W/$NAME.erofs")
sha=$(sha256sum "$W/$NAME.erofs" | cut -d' ' -f1)
zstd -19 -T0 -c "$W/$NAME.erofs" | split -b 1900M -d -a 2 - "$OUT/$NAME.erofs.zst."
rm -f "$W/$NAME.erofs"
(cd "$OUT" && python3 - "$DISTRO" "$DE" "$size" "$sha" <<'PY'
import glob, hashlib, json, os, sys
distro, de, size, sha = sys.argv[1:]
parts = []
for name in sorted(glob.glob(f"{distro}-{de}.erofs.zst.*")):
    h = hashlib.sha256()
    with open(name, "rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            h.update(block)
    parts.append({"file": name, "size": os.path.getsize(name), "sha256": h.hexdigest()})
json.dump({"distro": distro, "desktop": de, "file": f"{distro}-{de}.erofs",
           "size": int(size), "sha256": sha, "parts": parts},
          open(f"{distro}-{de}.json", "w"), indent=1)
PY
)
ls -la "$OUT"
