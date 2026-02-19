# 🪲 Scarab OS

A minimal Linux distribution built from scratch with a ports-based package system.

## Philosophy

- **Minimal** — Only what you need, nothing more
- **Source-based** — Everything built from source via ports, with prebuilt packages available
- **Simple** — Shell scripts, no bloat, no systemd
- **Modern** — Latest stable versions of everything

## Core Stack

| Component | Version | Role |
|-----------|---------|------|
| [Linux](https://kernel.org) | 6.12.73 LTS | Kernel |
| [musl](https://musl.libc.org) | 1.2.5 | C Library |
| [BusyBox](https://busybox.net) | 1.37.0 | Core Utilities |
| [Nitro](https://git.vuxu.org/nitro) | latest | Init System / Process Supervisor |
| [GCC](https://gcc.gnu.org) | 15.2.0 | Compiler |
| [Limine](https://limine-bootloader.org) | 10.x | Bootloader (BIOS + UEFI) |

## Included Packages

| Category | Packages |
|----------|----------|
| **Core** | musl, BusyBox, Nitro, Linux, zlib, mbedTLS, Limine |
| **Network** | curl, Dropbear (SSH), dhcpcd, iproute2 |
| **Filesystem** | e2fsprogs |
| **Editors** | nano |
| **Monitoring** | htop |
| **Development** | GCC, binutils, make, cmake, ninja, git, bash, bison, flex |
| **Libraries** | ncurses, zlib, mbedTLS |

## Quick Start

### Boot the ISO

```sh
# BIOS
qemu-system-x86_64 -cdrom scarab-0.1.0-x86_64.iso -m 512M

# UEFI
qemu-system-x86_64 -cdrom scarab-0.1.0-x86_64.iso -m 512M \
    -bios /usr/share/ovmf/OVMF.fd
```

### Enable Services

Scarab uses [Nitro](https://git.vuxu.org/nitro) as its init system. Services are directories in `/etc/nitro/`:

```sh
# Enable networking
rm /etc/nitro/dhcpcd/down
nitroctl up dhcpcd

# Enable SSH
rm /etc/nitro/dropbear/down
nitroctl up dropbear

# Check status
nitroctl status
```

### Package Management

Scarab uses [scarab-pm](https://github.com/scarab-os/scarab-pm) — a fast Rust-based package manager:

```sh
scarab sync              # Sync package database
scarab install <pkg>     # Install prebuilt package
scarab remove <pkg>      # Remove package
scarab search <query>    # Search packages
scarab list              # List installed packages
scarab upgrade           # Upgrade all packages
scarab build <pkg>       # Build from source (Portfile)
```

## Ports System

Every package has a `Portfile` — a simple shell script describing how to build it:

```
ports/
├── core/       # Essential (kernel, libc, busybox, ...)
├── lib/        # Libraries (ncurses, readline, ...)
├── devel/      # Development (gcc, cmake, git, ...)
├── net/        # Networking (dropbear, curl, ...)
└── extra/      # Optional (nano, htop, vim, ...)
```

### Portfile Example

```sh
# Description: Lightweight TLS/crypto library
# URL: https://github.com/Mbed-TLS/mbedtls
# Depends: zlib

name=mbedtls
version=3.6.5
source=https://github.com/Mbed-TLS/mbedtls/releases/download/mbedtls-$version/mbedtls-$version.tar.bz2

build() {
    cd $name-$version
    mkdir build && cd build
    cmake .. -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release
    make -j$(nproc)
    make DESTDIR=$PKG install
}
```

Patches are supported via a `patches/` directory next to the Portfile.

## Building from Source

See [docs/BUILDING.md](docs/BUILDING.md) for full instructions.

```sh
# 1. Build cross-compilation toolchain
./scripts/build-toolchain.sh

# 2. Build root filesystem
./scripts/build-rootfs.sh ./rootfs

# 3. Cross-compile packages into rootfs
# 4. Create bootable ISO
./scripts/build-iso.sh ./rootfs
```

### Build Requirements

- GCC (host compiler)
- Make, CMake, Meson, Ninja
- curl, tar, xz, gzip
- xorriso (ISO creation)
- qemu-system-x86_64 (testing)

## Project Structure

```
scarab/
├── scarab              # Legacy shell package manager
├── ports/              # Package build recipes
│   ├── core/
│   ├── lib/
│   ├── devel/
│   ├── net/
│   └── extra/
├── scripts/
│   ├── build-toolchain.sh
│   ├── build-rootfs.sh
│   └── build-iso.sh
├── config/
│   └── scarab.conf
├── docs/
│   └── BUILDING.md
├── LICENSE
└── README.md
```

## Related Repositories

- [scarab-os/scarab-pm](https://github.com/scarab-os/scarab-pm) — Package manager (Rust)
- [scarab-os/packages](https://github.com/scarab-os/packages) — Prebuilt binary packages

## License

MIT — see [LICENSE](LICENSE)
