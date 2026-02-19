# Building Scarab OS

## Overview

Building Scarab OS involves 4 main steps:

1. **Build the cross-compilation toolchain**
2. **Build the root filesystem**
3. **Cross-compile core packages**
4. **Create a bootable ISO**

## Prerequisites

A Linux host with:
- GCC (host compiler)
- Make, CMake, Meson, Ninja
- curl or wget
- tar, xz, gzip, bzip2
- git
- xorriso (for ISO creation)
- qemu-system-x86_64 (for testing)

## Step 1: Build Toolchain

```sh
./scripts/build-toolchain.sh /opt/scarab-toolchain
export PATH="/opt/scarab-toolchain/bin:$PATH"
```

This builds:
- Binutils 2.46 (cross)
- GCC 15.2.0 (cross, 2-stage)
- musl 1.2.5 (target libc)

Target triplet: `x86_64-scarab-linux-musl`

## Step 2: Build Root Filesystem

```sh
./scripts/build-rootfs.sh ./rootfs
```

Creates the directory layout, config files, rc scripts, and installs the ports tree.

## Step 3: Build Core Packages

Cross-compile and install packages into the rootfs:

```sh
export SCARAB_ROOT=./rootfs
export SCARAB_PORTS=./ports

# Core packages (in order)
scarab install busybox
scarab install nitro
scarab install zlib
scarab install mbedtls
scarab install curl
scarab install dropbear
scarab install dhcpcd
scarab install e2fsprogs
```

## Step 4: Build Kernel

```sh
cd rootfs
scarab install linux
```

Or manually:
```sh
cd toolchain-build/src/linux-6.12.73
make ARCH=x86_64 CROSS_COMPILE=x86_64-scarab-linux-musl- defconfig
make ARCH=x86_64 CROSS_COMPILE=x86_64-scarab-linux-musl- -j$(nproc)
cp arch/x86/boot/bzImage ../../../rootfs/boot/vmlinuz-6.12.73
```

## Step 5: Create ISO

```sh
./scripts/build-iso.sh ./rootfs
```

## Step 6: Test

```sh
qemu-system-x86_64 -cdrom scarab-0.1.0-x86_64.iso -m 512M -serial stdio
```

## Project Structure

```
scarab/
├── scarab                  # Package manager
├── config/
│   └── scarab.conf         # Build configuration
├── scripts/
│   ├── build-toolchain.sh  # Cross-toolchain builder
│   ├── build-rootfs.sh     # Root filesystem creator
│   └── build-iso.sh        # ISO creator
├── ports/
│   ├── core/               # Essential packages
│   ├── lib/                # Libraries
│   ├── devel/              # Development tools
│   ├── net/                # Networking
│   └── extra/              # Optional packages
└── docs/
    └── BUILDING.md         # This file
```
