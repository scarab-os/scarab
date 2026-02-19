#!/bin/sh
# build-package.sh - Build a single package from its Portfile
#
# Usage: ./scripts/build-package.sh <category> <name> [output-dir]
#
# Requires: CROSS, SYSROOT env vars set, toolchain in PATH

set -e

PKG_CAT="${1:?Usage: build-package.sh <category> <name> [output-dir]}"
PKG_NAME="${2:?Usage: build-package.sh <category> <name> [output-dir]}"
OUTPUT_DIR="${3:-$PWD}"

PORTDIR="$(cd "$(dirname "$0")/.." && pwd)/ports/${PKG_CAT}/${PKG_NAME}"
PORTFILE="${PORTDIR}/Portfile"

[ -f "$PORTFILE" ] || { echo "ERROR: $PORTFILE not found"; exit 1; }

# Defaults
: "${CROSS:=x86_64-scarab-linux-musl}"
: "${SYSROOT:=}"
: "${MAKEFLAGS:=-j$(nproc)}"
export MAKEFLAGS

export CC="${CROSS}-gcc"
export CXX="${CROSS}-g++"
export AR="${CROSS}-ar"
export RANLIB="${CROSS}-ranlib"
export STRIP="${CROSS}-strip"

WORK="$(mktemp -d)"
PKG="$(mktemp -d)"
export PKG SRC="$WORK"

trap "rm -rf '$WORK' '$PKG'" EXIT

echo "==> Building ${PKG_NAME}..."

# Source Portfile (sets name, version, source, build())
. "$PORTFILE"

echo "  -> ${name} ${version}"

# Download source
if [ -n "$source" ]; then
    cd "$WORK"
    SRCFILE="$(basename "$source")"
    echo "  -> Downloading ${SRCFILE}..."
    curl -fL -o "$SRCFILE" "$source"
    case "$SRCFILE" in
        *.tar.gz|*.tgz)  tar xzf "$SRCFILE" ;;
        *.tar.xz|*.txz)  tar xJf "$SRCFILE" ;;
        *.tar.bz2|*.tbz2) tar xjf "$SRCFILE" ;;
        *.tar.zst)        zstd -d "$SRCFILE" --stdout | tar xf - ;;
        *.tar)            tar xf "$SRCFILE" ;;
    esac
fi

# Apply patches
if [ -d "${PORTDIR}/patches" ]; then
    for p in "${PORTDIR}/patches"/*.patch; do
        [ -f "$p" ] || continue
        echo "  -> Applying patch: $(basename "$p")"
        patch -d "$WORK" -p1 < "$p"
    done
fi

# Build
cd "$WORK"
echo "  -> Running build()..."
build

# Create tarball
ARCH="${CROSS%%-*}"
TARBALL="${name}-${version}-${ARCH}.tar.gz"

if [ "$(ls -A "$PKG" 2>/dev/null)" ]; then
    cd "$PKG"
    tar czf "${OUTPUT_DIR}/${TARBALL}" .
    cd "${OUTPUT_DIR}"
    sha256sum "$TARBALL" > "${TARBALL}.sha256"
    echo "==> ✅ ${TARBALL} ($(du -h "$TARBALL" | cut -f1))"
else
    echo "==> ❌ Empty output for ${name}"
    exit 1
fi
