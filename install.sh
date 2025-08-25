#!/bin/sh

# PigeonLinux Main Installer Script
set -e

# Цвета
RED=$(printf '\033[31m')
GREEN=$(printf '\033[32m')
YELLOW=$(printf '\033[33m')
BLUE=$(printf '\033[34m')
RESET=$(printf '\033[0m')

# Пути
CONFIG_FILE="config.cfg"
DESTDIR="/mnt"

error() {
    echo "${RED}Error: $1${RESET}" >&2
    exit 1
}

info() {
    echo "${GREEN}$1${RESET}"
}

warning() {
    echo "${YELLOW}Warning: $1${RESET}"
}

check_dependencies() {
    for dep in cfdisk parted mkfs.$FS_TYPE grub-install chroot; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            error "Missing dependency: $dep"
        fi
    done
}

check_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        error "Configuration file not found. Run 'make menuconfig' first!"
    fi
    . "$CONFIG_FILE"
}

check_partitions() {
    info "Checking partitions..."
    
    if [ "$BOOT_ENABLE" = "y" ] && [ ! -b "${TARGET_DISK}1" ]; then
        error "Boot partition ${TARGET_DISK}1 not found!"
    fi
    
    if [ ! -b "${TARGET_DISK}2" ]; then
        error "Root partition ${TARGET_DISK}2 not found!"
    fi
    
    if [ "$SWAP_ENABLE" = "y" ] && [ ! -b "${TARGET_DISK}3" ]; then
        error "Swap partition ${TARGET_DISK}3 not found!"
    fi
    
    info "All partitions verified ✓"
}

prepare_filesystems() {
    info "Creating filesystems..."
    
    if [ "$BOOT_ENABLE" = "y" ]; then
        mkfs.$FS_TYPE -L boot "${TARGET_DISK}1"
    fi
    
    mkfs.$FS_TYPE -L root "${TARGET_DISK}2"
    
    if [ "$SWAP_ENABLE" = "y" ]; then
        mkswap -L swap "${TARGET_DISK}3"
    fi
}

mount_filesystems() {
    info "Mounting filesystems..."
    
    mkdir -p "$DESTDIR"
    mount "${TARGET_DISK}2" "$DESTDIR"
    
    if [ "$BOOT_ENABLE" = "y" ]; then
        mkdir -p "$DESTDIR/boot"
        mount "${TARGET_DISK}1" "$DESTDIR/boot"
    fi
    
    if [ "$SWAP_ENABLE" = "y" ]; then
        swapon "${TARGET_DISK}3"
    fi
}

copy_system() {
    info "Copying system files..."
    
    cp -a /bin "$DESTDIR/"
    cp -a /etc "$DESTDIR/"
    cp -a /lib "$DESTDIR/"
    cp -a /root "$DESTDIR/"
    cp -a /sbin "$DESTDIR/"
    cp -a /usr "$DESTDIR/"
    cp -a /var "$DESTDIR/"
    mkdir -p "$DESTDIR/"{dev,proc,sys,tmp,home}
}

setup_config() {
    info "Setting up configuration..."
    
    # fstab
    cat > "$DESTDIR/etc/fstab" << EOF
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
${TARGET_DISK}2  /               $FS_TYPE    defaults        1       1
EOF
    
    if [ "$BOOT_ENABLE" = "y" ]; then
        echo "${TARGET_DISK}1  /boot           $FS_TYPE    defaults        0       2" >> "$DESTDIR/etc/fstab"
    fi
    
    if [ "$SWAP_ENABLE" = "y" ]; then
        echo "${TARGET_DISK}3  none            swap    sw              0       0" >> "$DESTDIR/etc/fstab"
    fi
    
    cat >> "$DESTDIR/etc/fstab" << EOF
proc            /proc           proc    defaults        0       0
sysfs           /sys            sysfs   defaults        0       0
tmpfs           /tmp            tmpfs   defaults        0       0
EOF
    
    # hostname
    echo "$HOSTNAME" > "$DESTDIR/etc/hostname"
}

install_bootloader() {
    info "Installing GRUB bootloader..."
    grub-install --target=$GRUB_TARGET --root-directory=$DESTDIR $TARGET_DISK
}

main() {
    echo "${BLUE}=== PigeonLinux System Installer ===${RESET}"
    
    check_config
    check_dependencies
    check_partitions
    
    echo "${YELLOW}Target disk: $TARGET_DISK${RESET}"
    echo "${YELLOW}This will ERASE ALL DATA on $TARGET_DISK!${RESET}"
    printf "${YELLOW}Are you sure you want to continue? (y/N): ${RESET}"
    read -r confirm
    
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        error "Installation cancelled"
    fi
    
    prepare_filesystems
    mount_filesystems
    copy_system
    setup_config
    install_bootloader
    
    echo ""
    echo "${GREEN}=== Installation Completed Successfully! ===${RESET}"
    echo ""
    echo "Next steps:"
    echo "1. Reboot your system"
    echo "2. Select PigeonLinux from GRUB menu"
    echo "3. Login as root"
    echo ""
    echo "Thank you for choosing PigeonLinux! 🐦"
}

main "$@"
