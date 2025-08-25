#!/bin/sh

# Wrapper for cfdisk with partition validation
TARGET_DISK="$1"
CONFIG_FILE="../.config"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

error() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

check_disk() {
    if [ ! -b "$TARGET_DISK" ]; then
        error "Disk $TARGET_DISK not found"
    fi
}

load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        error "Configuration file not found. Run 'make menuconfig' first!"
    fi
    . "$CONFIG_FILE"
}

check_partitions() {
    echo -e "${YELLOW}Please create the following partitions in cfdisk:${NC}"
    echo ""
    
    local expected_partitions=()
    local part_num=1
    
    if [ "$BOOT_ENABLE" = "y" ]; then
        echo -e "Partition $part_num: Boot - ${GREEN}$BOOT_SIZE${NC} (${FS_TYPE})"
        expected_partitions+=("$part_num")
        part_num=$((part_num + 1))
    fi
    
    echo -e "Partition $part_num: Root - ${GREEN}$ROOT_SIZE${NC} (${FS_TYPE})"
    expected_partitions+=("$part_num")
    part_num=$((part_num + 1))
    
    if [ "$SWAP_ENABLE" = "y" ]; then
        echo -e "Partition $part_num: Swap - ${GREEN}$SWAP_SIZE${NC} (linux swap)"
        expected_partitions+=("$part_num")
    fi
    
    echo ""
    echo -e "${YELLOW}Press Enter to start cfdisk...${NC}"
    read -r
}

verify_partitions() {
    echo -e "${GREEN}Verifying partitions...${NC}"
    
    local found_boot=0
    local found_root=0
    local found_swap=0
    
    # Check if partitions exist
    if [ "$BOOT_ENABLE" = "y" ] && [ ! -b "${TARGET_DISK}1" ]; then
        error "Boot partition (${TARGET_DISK}1) not found!"
    else
        found_boot=1
    fi
    
    if [ ! -b "${TARGET_DISK}2" ]; then
        error "Root partition (${TARGET_DISK}2) not found!"
    else
        found_root=1
    fi
    
    if [ "$SWAP_ENABLE" = "y" ] && [ ! -b "${TARGET_DISK}3" ]; then
        error "Swap partition (${TARGET_DISK}3) not found!"
    else
        found_swap=1
    fi
    
    echo -e "${GREEN}✓ All required partitions found${NC}"
    
    # Verify partition types (basic check)
    if [ "$found_boot" -eq 1 ]; then
        echo -e "✓ Boot partition: ${TARGET_DISK}1"
    fi
    if [ "$found_root" -eq 1 ]; then
        echo -e "✓ Root partition: ${TARGET_DISK}2"
    fi
    if [ "$found_swap" -eq 1 ]; then
        echo -e "✓ Swap partition: ${TARGET_DISK}3"
    fi
}

main() {
    check_disk
    load_config
    check_partitions
    
    # Start cfdisk
    cfdisk "$TARGET_DISK"
    
    # Verify partitions after cfdisk
    verify_partitions
    
    echo -e "${GREEN}Partitioning completed successfully!${NC}"
    echo -e "Run 'make all' to continue with installation."
}

main "$@"
