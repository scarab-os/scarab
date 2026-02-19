#!/bin/sh
# build-rootfs.sh - Build Scarab OS root filesystem
#
# Requires: cross-toolchain built via build-toolchain.sh
#
# Usage: ./scripts/build-rootfs.sh [ROOTFS_DIR]

set -e

ROOTFS="${1:-$(pwd)/rootfs}"
TARGET="x86_64-scarab-linux-musl"
TOOLCHAIN="/opt/scarab-toolchain"

RED='\033[0;31m'
GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m'

msg() { printf "${GREEN}==>${NC} ${BOLD}%s${NC}\n" "$*"; }

export PATH="$TOOLCHAIN/bin:$PATH"

# === Create directory structure ===

msg "Creating root filesystem layout..."

mkdir -p "$ROOTFS"/{bin,sbin,usr/{bin,sbin,lib,include,share,ports},etc,dev,proc,sys,run,tmp,var/{log,lib/scarab/db,cache/scarab/{sources,work}},home,root,boot}

chmod 1777 "$ROOTFS/tmp"
chmod 0750 "$ROOTFS/root"

# === Essential files ===

msg "Creating essential configuration files..."

# /etc/passwd
cat > "$ROOTFS/etc/passwd" <<'EOF'
root:x:0:0:root:/root:/bin/sh
nobody:x:65534:65534:nobody:/nonexistent:/bin/false
EOF

# /etc/group
cat > "$ROOTFS/etc/group" <<'EOF'
root:x:0:
bin:x:1:
sys:x:2:
tty:x:5:
disk:x:6:
wheel:x:10:root
nobody:x:65534:
EOF

# /etc/shadow
cat > "$ROOTFS/etc/shadow" <<'EOF'
root::0:0:99999:7:::
nobody:!:0:0:99999:7:::
EOF
chmod 0640 "$ROOTFS/etc/shadow"

# /etc/hostname
echo "scarab" > "$ROOTFS/etc/hostname"

# /etc/hosts
cat > "$ROOTFS/etc/hosts" <<'EOF'
127.0.0.1   localhost
127.0.1.1   scarab
::1         localhost
EOF

# /etc/os-release
cat > "$ROOTFS/etc/os-release" <<'EOF'
NAME="Scarab OS"
VERSION="0.1.0"
ID=scarab
PRETTY_NAME="Scarab OS 0.1.0"
HOME_URL="https://github.com/scarab-os"
EOF

# /etc/fstab
cat > "$ROOTFS/etc/fstab" <<'EOF'
# <device>  <mount>  <type>  <options>        <dump>  <pass>
/dev/sda1   /        ext4    defaults,noatime  0       1
proc        /proc    proc    defaults          0       0
sysfs       /sys     sysfs   defaults          0       0
devtmpfs    /dev     devtmpfs defaults         0       0
tmpfs       /tmp     tmpfs   defaults          0       0
tmpfs       /run     tmpfs   defaults          0       0
EOF

# /etc/profile
cat > "$ROOTFS/etc/profile" <<'EOF'
export PATH="/usr/sbin:/usr/bin:/sbin:/bin"
export TERM="linux"
export LANG="C"
export PS1='\[\033[1;32m\]\u@\h\[\033[0m\]:\[\033[1;34m\]\w\[\033[0m\]\$ '

# Load user profile
[ -f "$HOME/.profile" ] && . "$HOME/.profile"
EOF

# /etc/inittab (for BusyBox init / Nitro)
cat > "$ROOTFS/etc/inittab" <<'EOF'
::sysinit:/etc/rc.d/rc.boot
::respawn:/sbin/getty 38400 tty1
::respawn:/sbin/getty 38400 tty2
::respawn:/sbin/getty 38400 tty3
::ctrlaltdel:/sbin/reboot
::shutdown:/etc/rc.d/rc.shutdown
EOF

# === RC scripts ===

mkdir -p "$ROOTFS/etc/rc.d"

# Boot script
cat > "$ROOTFS/etc/rc.d/rc.boot" <<'RCEOF'
#!/bin/sh
# Scarab OS boot script

echo "🪲 Scarab OS booting..."

# Mount virtual filesystems
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev
mkdir -p /dev/pts /dev/shm
mount -t devpts devpts /dev/pts
mount -t tmpfs tmpfs /dev/shm
mount -t tmpfs tmpfs /run
mount -t tmpfs tmpfs /tmp

# Set hostname
[ -f /etc/hostname ] && hostname $(cat /etc/hostname)

# Bring up loopback
ip link set lo up

# Mount all filesystems
mount -a

# Set clock
hwclock --hctosys 2>/dev/null || true

# Start syslog
syslogd 2>/dev/null || true

# Network
if [ -x /sbin/dhcpcd ]; then
    dhcpcd -q &
fi

echo "🪲 Scarab OS ready."
RCEOF

# Shutdown script
cat > "$ROOTFS/etc/rc.d/rc.shutdown" <<'RCEOF'
#!/bin/sh
# Scarab OS shutdown script

echo "🪲 Scarab OS shutting down..."

# Kill all processes
killall5 -15
sleep 2
killall5 -9

# Save clock
hwclock --systohc 2>/dev/null || true

# Unmount
sync
umount -a -r

echo "🪲 Goodbye."
RCEOF

chmod +x "$ROOTFS/etc/rc.d/rc.boot" "$ROOTFS/etc/rc.d/rc.shutdown"

# === Install scarab package manager ===

msg "Installing scarab package manager..."
install -m 755 "$(dirname "$0")/../scarab" "$ROOTFS/usr/bin/scarab"

# === Copy ports tree ===

msg "Copying ports tree..."
cp -r "$(dirname "$0")/../ports"/* "$ROOTFS/usr/ports/"

msg "Root filesystem created at: $ROOTFS"
msg ""
msg "Next steps:"
msg "  1. Cross-compile BusyBox and install to rootfs"
msg "  2. Cross-compile Nitro and install"
msg "  3. Build the kernel"
msg "  4. Create bootable ISO"
