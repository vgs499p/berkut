set -eux
apk add --no-cache busybox-static cpio gzip file build-base linux-headers curl >/dev/null
cd /tmp && curl -fsSL https://cdn.kernel.org/pub/linux/kernel/people/tytso/e2fsprogs/v1.47.2/e2fsprogs-1.47.2.tar.xz | tar xJ
cd e2fsprogs-1.47.2 && ./configure --disable-nls --disable-fuse2fs --disable-elf-shlibs --disable-defrag --disable-debugfs --disable-imager --disable-uuidd LDFLAGS="-static -Wl,-z,max-page-size=65536" >/dev/null && make -j6 >/dev/null 2>&1
E=/tmp/e2fsprogs-1.47.2
R=/tmp/base; rm -rf $R; mkdir -p $R/bin $R/sbin $R/dev $R/newroot $R/proc $R/sys
cp /bin/busybox.static $R/bin/busybox
for p in mke2fs e2fsck resize2fs dumpe2fs; do
  for d in misc e2fsck resize; do [ -f $E/$d/$p ] && cp $E/$d/$p $R/sbin/$p && strip $R/sbin/$p && break; done
done
cd $R
for l in '[' cp echo mkdir mount printf sh sleep sync umount cat ls rm mv ln grep sed tr chmod mknod cut head; do ln -s busybox bin/$l; done
ln -s ../bin/busybox sbin/blkid; ln -s ../bin/busybox sbin/switch_root; ln -s mke2fs sbin/mkfs.ext4
mknod -m 600 dev/console c 5 1; mknod -m 666 dev/null c 1 3
printf '#!/bin/sh\necho "UML_BOOT_BASE_ERROR:no per-run /init follows the boot base"\nexit 1\n' > init; chmod 755 init
file bin/busybox sbin/mke2fs
find . | LC_ALL=C sort | cpio -o -H newc -R 0:0 | gzip -9 -n > /out/uml-boot-base-aarch64.cpio.gz
ls -la /out
