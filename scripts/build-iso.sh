#!/bin/sh
# build-iso.sh - Create bootable Scarab OS ISO with Limine
#
# Requires: rootfs built, kernel built, xorriso, limine
#
# Usage: ./scripts/build-iso.sh [ROOTFS_DIR]

set -e

ROOTFS="${1:-$(pwd)/rootfs}"
ISODIR="$(pwd)/iso-build"
OUTPUT="$(pwd)/scarab-0.1.0-x86_64.iso"
LIMINE_DIR="${LIMINE_DIR:-/usr/share/limine}"

RED='\033[0;31m'
GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m'

msg() { printf "${GREEN}==>${NC} ${BOLD}%s${NC}\n" "$*"; }
err() { printf "${RED}==> ERROR:${NC} %s\n" "$*" >&2; exit 1; }

[ -d "$ROOTFS" ] || err "Rootfs not found: $ROOTFS"

msg "Creating bootable ISO with Limine..."

# Setup ISO structure
rm -rf "$ISODIR"
mkdir -p "$ISODIR"/{boot/limine,EFI/BOOT}

# Create initramfs from rootfs
msg "Creating initramfs..."
cd "$ROOTFS"
find . | cpio -H newc -o 2>/dev/null | gzip -9 > "$ISODIR/boot/initramfs.gz"

# Copy kernel
if ls "$ROOTFS/boot/vmlinuz-"* 1>/dev/null 2>&1; then
    cp "$ROOTFS/boot/vmlinuz-"* "$ISODIR/boot/vmlinuz"
else
    err "No kernel found in rootfs/boot/"
fi

# Limine configuration
cat > "$ISODIR/boot/limine/limine.conf" <<'EOF'
timeout: 5

/Scarab OS
    protocol: linux
    kernel_path: boot():/boot/vmlinuz
    module_path: boot():/boot/initramfs.gz
    kernel_cmdline: root=/dev/ram0 rw quiet
EOF

# Copy Limine files
# BIOS
for f in limine-bios.sys limine-bios-cd.bin; do
    if [ -f "$LIMINE_DIR/$f" ]; then
        cp "$LIMINE_DIR/$f" "$ISODIR/boot/limine/"
    fi
done

# UEFI
if [ -f "$LIMINE_DIR/BOOTX64.EFI" ]; then
    cp "$LIMINE_DIR/BOOTX64.EFI" "$ISODIR/EFI/BOOT/"
fi

# Build ISO
command -v xorriso >/dev/null 2>&1 || err "xorriso not found"

xorriso -as mkisofs \
    -b boot/limine/limine-bios-cd.bin \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    --efi-boot EFI/BOOT/BOOTX64.EFI \
    -efi-boot-part \
    --efi-boot-image \
    --protective-msdos-label \
    -o "$OUTPUT" \
    "$ISODIR"

# Install Limine BIOS stages
if command -v limine >/dev/null 2>&1; then
    limine bios-install "$OUTPUT"
    msg "Limine BIOS stages installed"
fi

# Cleanup
rm -rf "$ISODIR"

msg "ISO created: $OUTPUT"
msg "  BIOS + UEFI bootable 🪲"
msg ""
msg "Test with:"
msg "  BIOS: qemu-system-x86_64 -cdrom $OUTPUT -m 512M"
msg "  UEFI: qemu-system-x86_64 -cdrom $OUTPUT -m 512M -bios /usr/share/ovmf/OVMF.fd"
