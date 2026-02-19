#!/bin/sh
# build-toolchain.sh - Build Scarab OS cross-compilation toolchain
#
# Toolchain: Binutils + GCC (2-stage) + musl
# Target: x86_64-scarab-linux-musl
#
# Usage: ./scripts/build-toolchain.sh [PREFIX]

set -e

PREFIX="$(cd "$(dirname "${1:-.}")" && pwd)/$(basename "${1:-toolchain}")"
PREFIX="${PREFIX:-/opt/scarab-toolchain}"
TARGET="x86_64-scarab-linux-musl"
SYSROOT="$PREFIX/$TARGET"
JOBS="$(nproc)"

# Versions
BINUTILS_VER="2.46.0"
GCC_VER="15.2.0"
GMP_VER="6.3.0"
MPFR_VER="4.2.2"
MPC_VER="1.3.1"
LINUX_VER="6.12.73"
MUSL_VER="1.2.5"

BUILDDIR="$(pwd)/toolchain-build"
SRCDIR="$BUILDDIR/src"
LOGDIR="$BUILDDIR/logs"

GREEN='\033[0;32m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

msg() { printf "${GREEN}==>${NC} ${BOLD}%s${NC}\n" "$*"; }
err() { printf "${RED}==> ERROR:${NC} %s\n" "$*" >&2; exit 1; }

mkdir -p "$SRCDIR" "$LOGDIR" "$PREFIX" "$SYSROOT"
export PATH="$PREFIX/bin:$PATH"

# === Download ===
download() {
    local url="$1" dest="$SRCDIR/$(basename "$1")"
    [ -f "$dest" ] && return
    msg "Downloading $(basename "$url")..."
    curl -fL -o "$dest" "$url"
}

msg "Downloading sources..."
download "https://ftp.gnu.org/gnu/binutils/binutils-$BINUTILS_VER.tar.xz"
download "https://ftp.gnu.org/gnu/gcc/gcc-$GCC_VER/gcc-$GCC_VER.tar.xz"
download "https://ftp.gnu.org/gnu/gmp/gmp-$GMP_VER.tar.xz"
download "https://ftp.gnu.org/gnu/mpfr/mpfr-$MPFR_VER.tar.xz"
download "https://ftp.gnu.org/gnu/mpc/mpc-$MPC_VER.tar.gz"
download "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-$LINUX_VER.tar.xz"
download "https://musl.libc.org/releases/musl-$MUSL_VER.tar.gz"

# === Extract ===
extract() {
    local archive="$1" name="$2"
    [ -d "$SRCDIR/$name" ] && return
    msg "Extracting $name..."
    case "$archive" in
        *.tar.xz) tar xJf "$archive" -C "$SRCDIR" ;;
        *.tar.gz) tar xzf "$archive" -C "$SRCDIR" ;;
    esac
}

extract "$SRCDIR/binutils-$BINUTILS_VER.tar.xz" "binutils-$BINUTILS_VER"
extract "$SRCDIR/gcc-$GCC_VER.tar.xz" "gcc-$GCC_VER"
extract "$SRCDIR/gmp-$GMP_VER.tar.xz" "gmp-$GMP_VER"
extract "$SRCDIR/mpfr-$MPFR_VER.tar.xz" "mpfr-$MPFR_VER"
extract "$SRCDIR/mpc-$MPC_VER.tar.gz" "mpc-$MPC_VER"
extract "$SRCDIR/linux-$LINUX_VER.tar.xz" "linux-$LINUX_VER"
extract "$SRCDIR/musl-$MUSL_VER.tar.gz" "musl-$MUSL_VER"

cd "$SRCDIR/gcc-$GCC_VER"
[ -d gmp ] || ln -sf "../gmp-$GMP_VER" gmp
[ -d mpfr ] || ln -sf "../mpfr-$MPFR_VER" mpfr
[ -d mpc ] || ln -sf "../mpc-$MPC_VER" mpc

# === Step 1: Linux Headers ===
msg "Installing Linux headers..."
cd "$SRCDIR/linux-$LINUX_VER"
make ARCH=x86_64 INSTALL_HDR_PATH="$SYSROOT/usr" headers_install \
    > "$LOGDIR/linux-headers.log" 2>&1 || { echo "FAILED - see log:"; tail -30 "$LOGDIR/linux-headers.log"; exit 1; }
msg "Linux headers OK"

# === Step 2: Binutils ===
msg "Building binutils..."
rm -rf "$BUILDDIR/binutils-build"
mkdir -p "$BUILDDIR/binutils-build" && cd "$BUILDDIR/binutils-build"
"$SRCDIR/binutils-$BINUTILS_VER/configure" \
    --prefix="$PREFIX" \
    --target="$TARGET" \
    --with-sysroot="$SYSROOT" \
    --disable-nls \
    --disable-werror \
    > "$LOGDIR/binutils-configure.log" 2>&1 || { cat "$LOGDIR/binutils-configure.log" | tail -20; exit 1; }
make -j$JOBS > "$LOGDIR/binutils-make.log" 2>&1 || { echo "FAILED - see log:"; tail -30 "$LOGDIR/binutils-make.log"; exit 1; }
make install > "$LOGDIR/binutils-install.log" 2>&1 || { echo "FAILED - see log:"; tail -30 "$LOGDIR/binutils-install.log"; exit 1; }
msg "Binutils OK"

# === Step 3: GCC Stage 1 (C only, freestanding) ===
msg "Building GCC stage 1..."
rm -rf "$BUILDDIR/gcc-build-stage1"
mkdir -p "$BUILDDIR/gcc-build-stage1" && cd "$BUILDDIR/gcc-build-stage1"
"$SRCDIR/gcc-$GCC_VER/configure" \
    --prefix="$PREFIX" \
    --target="$TARGET" \
    --with-sysroot="$SYSROOT" \
    --enable-languages=c \
    --disable-multilib \
    --disable-nls \
    --disable-shared \
    --disable-threads \
    --disable-libssp \
    --disable-libgomp \
    --disable-libquadmath \
    --disable-libatomic \
    --disable-libstdcxx \
    --without-headers \
    --with-newlib \
    > "$LOGDIR/gcc-stage1-configure.log" 2>&1 || { echo "FAILED - see log:"; tail -30 "$LOGDIR/gcc-stage1-configure.log"; exit 1; }
make -j$JOBS all-gcc > "$LOGDIR/gcc-stage1-make.log" 2>&1 || { echo "FAILED - see log:"; tail -30 "$LOGDIR/gcc-stage1-make.log"; exit 1; }
make install-gcc > "$LOGDIR/gcc-stage1-install.log" 2>&1 || { echo "FAILED - see log:"; tail -30 "$LOGDIR/gcc-stage1-install.log"; exit 1; }
make -j$JOBS all-target-libgcc > "$LOGDIR/gcc-stage1-libgcc.log" 2>&1 || { echo "FAILED - see log:"; tail -30 "$LOGDIR/gcc-stage1-libgcc.log"; exit 1; }
make install-target-libgcc > "$LOGDIR/gcc-stage1-libgcc-install.log" 2>&1 || { echo "FAILED - see log:"; tail -30 "$LOGDIR/gcc-stage1-libgcc-install.log"; exit 1; }
msg "GCC stage 1 OK"

# === Step 4: musl ===
msg "Building musl..."
rm -rf "$BUILDDIR/musl-build"
mkdir -p "$BUILDDIR/musl-build" && cd "$BUILDDIR/musl-build"
"$SRCDIR/musl-$MUSL_VER/configure" \
    --prefix=/usr \
    --host="$TARGET" \
    --syslibdir=/lib \
    CROSS_COMPILE="$TARGET-" \
    > "$LOGDIR/musl-configure.log" 2>&1 || { echo "FAILED - see log:"; tail -30 "$LOGDIR/musl-configure.log"; exit 1; }
make -j$JOBS > "$LOGDIR/musl-make.log" 2>&1 || { echo "FAILED - see log:"; tail -30 "$LOGDIR/musl-make.log"; exit 1; }
make DESTDIR="$SYSROOT" install > "$LOGDIR/musl-install.log" 2>&1 || { echo "FAILED - see log:"; tail -30 "$LOGDIR/musl-install.log"; exit 1; }

# Fix: ld-musl symlink points to absolute /usr/lib/libc.so which doesn't exist in sysroot
# Copy the actual shared lib and create proper linker script
rm -f "$SYSROOT/lib/ld-musl-x86_64.so.1"
cp "$SYSROOT/usr/lib/libc.so" "$SYSROOT/lib/ld-musl-x86_64.so.1"
cat > "$SYSROOT/usr/lib/libc.so" <<LDSCRIPT
GROUP ( /lib/ld-musl-x86_64.so.1 libc.a )
LDSCRIPT
msg "musl OK"

# === Step 5: GCC Stage 2 (full C/C++) ===
msg "Building GCC stage 2..."
rm -rf "$BUILDDIR/gcc-build-stage2"
mkdir -p "$BUILDDIR/gcc-build-stage2" && cd "$BUILDDIR/gcc-build-stage2"
"$SRCDIR/gcc-$GCC_VER/configure" \
    --prefix="$PREFIX" \
    --target="$TARGET" \
    --with-sysroot="$SYSROOT" \
    --with-build-sysroot="$SYSROOT" \
    --with-native-system-header-dir=/usr/include \
    --enable-languages=c,c++ \
    --disable-multilib \
    --disable-nls \
    --enable-shared \
    --enable-threads=posix \
    --enable-default-pie \
    --enable-default-ssp \
    --disable-libsanitizer \
    --disable-fixincludes \
    > "$LOGDIR/gcc-stage2-configure.log" 2>&1 || { echo "FAILED - see log:"; tail -30 "$LOGDIR/gcc-stage2-configure.log"; exit 1; }
make -j$JOBS > "$LOGDIR/gcc-stage2-make.log" 2>&1 || { echo "FAILED - see log:"; tail -30 "$LOGDIR/gcc-stage2-make.log"; exit 1; }
make install > "$LOGDIR/gcc-stage2-install.log" 2>&1 || { echo "FAILED - see log:"; tail -30 "$LOGDIR/gcc-stage2-install.log"; exit 1; }
msg "GCC stage 2 OK"

# === Done ===
msg "============================================"
msg "  Scarab OS Toolchain - BUILD COMPLETE"
msg "============================================"
msg "Location: $PREFIX"
msg "Target:   $TARGET"
msg "Sysroot:  $SYSROOT"
msg ""

# Test
echo '#include <stdio.h>
int main() { printf("Hello Scarab!\\n"); return 0; }' > /tmp/test.c
if ${TARGET}-gcc -o /tmp/test-scarab /tmp/test.c 2>/dev/null; then
    msg "Test compile: OK"
    file /tmp/test-scarab
else
    msg "Test compile: FAILED (may need sysroot libs at runtime)"
fi

msg ""
msg "export PATH=\"$PREFIX/bin:\$PATH\""
