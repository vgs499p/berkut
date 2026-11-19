# Burrow

Arch Linux ARM with Plasma Mobile, running on an iPhone. Burrow is a build of
[Kernarium](https://github.com/imxieyi/Kernarium): a User-mode Linux kernel
compiled to native arm64 and run inside an iOS app, with guest programs on an
interpreter (or a JIT under StikDebug) and graphics through Virgl, Zink and
KosmicKrisp to Metal.

This repository holds only what Burrow adds. A build clones upstream
Kernarium at the commit in `upstream.env` and applies `patches/`.

## Layout

```text
patches/        Burrow's commits on upstream Kernarium (git am)
branding/       name, bundle identifier, icon sources and apply-branding.sh
image/          Arch Linux ARM + Plasma image recipe (runs in a container)
bootbase/       static BusyBox/e2fsprogs boot ramdisk recipe
scripts/        setup and build steps, in order below
Burrow.entitlements   the two memory entitlements the app needs
```

## Requirements

- An Apple silicon Mac with Xcode and the iOS SDK (the app targets iOS 27).
- Homebrew: `llvm`, `lld`, `make` (gmake), `meson`, `ninja`, `cmake`,
  `pkg-config`, `autoconf`, `automake`, `zstd`, `librsvg`, `imagemagick`.
- Apple's `container` CLI for the arm64 Linux steps
  (`container system start --enable-kernel-install` once).
- About 60 GB free for the build volume.

## Build

```sh
scripts/setup.sh            # case-sensitive volume, upstream clone, patches
scripts/build-kernels.sh    # Linux and Android UML kernels (~45 min)
scripts/build-boot-base.sh  # boot ramdisk, recorded in its descriptor
scripts/build-app.sh        # iOS dependencies, runtimes, frameworks, app
scripts/build-image.sh      # Arch Linux ARM + Plasma erofs image (~20 min)
scripts/make-ipa.sh "$PWD/Burrow.ipa"
```

`BURROW_BUILD_ROOT` moves the build volume (default `/Volumes/BurrowBuild`).
Everything there is generated and can be thrown away.

## Installing

The IPA is unsigned apart from an ad-hoc signature that carries the
entitlements. With Plume Impactor and a free Apple ID:

- set **Identifier** to an App ID the account already has, to stay under
  Apple's 10 App IDs per 7 days;
- enable **Only Register Main Bundle** and add `Burrow.entitlements`.

On first launch the app clones the bundled image into Documents and boots
it. Each launch starts the guest from the clean image; nothing written
inside the guest survives a relaunch.

Accounts: `uml`/`uml` (desktop, sudo), `root`/`root`, `alarm`/`alarm`.

## Branding

Edit `branding/branding.env` or replace the PNGs (1024×1024: light, dark,
tinted), then run `branding/apply-branding.sh` on the checkout and
regenerate patch 0003 (`git format-patch`). The guest's hostname is in
`image/build-arch-image.sh`.

## Notes from the first build

- Apple clang lacks Linux 6.18's `__counted_by` support; the kernel builds
  with Homebrew LLVM.
- The kernel's release string carries the local replay's commit, so
  `build-kernels.sh` writes the built release into the accepted descriptors.
- Upstream never published the `starter-20260928-boot-base-r1` ramdisk;
  `bootbase/` rebuilds an equivalent that passes `verify_base.py`.
- The Android runtime is built only because packaging and the Xcode project
  require it; Burrow never boots Android.
- Arch's SDDM needs `DisplayServer=wayland` (the image has no X server), and
  the Kernarium input devices need the udev rules from upstream's
  postmarketOS setup.
- Stock Arch Mesa reaches the host GPU through Virgl (`virgl (zink ...
  (Apple A18 GPU))`); do not force `MESA_LOADER_DRIVER_OVERRIDE=zink`, which
  falls back to llvmpipe.
- Without JIT everything runs on the interpreter, so Plasma is slow. The
  image turns off animations, effects, Baloo and session restore.
- Do not build the image with `mkfs.erofs -T0`: SDDM ignores configuration
  files dated at the epoch and falls back to X11 without autologin.
- Patch 0005 gives the Linux guest the iPhone's battery (the kernel's
  Kernarium Virtio battery driver, upstream Android-only); the mainline
  kernel is published as release `ca2`. NetworkManager replaces
  systemd-networkd so Plasma's indicator sees the (wired) SLiRP link.
- Plasma's on-screen keyboard can mangle hidden password prompts; `uml`'s
  password is `uml`. As root, `burrow-logs` shows why a session ended and
  `burrow-session plasma|plasma-mobile` switches the desktop.

## License

GPL-2.0-or-later, as upstream Kernarium (`LICENSE`). Anyone you give the IPA
to is entitled to its source: this repository plus upstream at the pinned
commit.
