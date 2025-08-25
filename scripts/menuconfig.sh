#!/bin/sh

# PigeonLinux Menu Config в стиле cfdisk
CONFIG_FILE="../config.cfg"  # Исправленный путь

# Цвета (как в cfdisk)
WHITE=$(printf '\033[37m')
BLACK=$(printf '\033[40m')
BLUE=$(printf '\033[44m')
CYAN=$(printf '\033[36m')
GREEN=$(printf '\033[32m')
YELLOW=$(printf '\033[33m')
RED=$(printf '\033[31m')
BOLD=$(printf '\033[1m')
REVERSE=$(printf '\033[7m')
RESET=$(printf '\033[0m')

# Стили как в cfdisk
HEADER_BG="$BLUE$WHITE$BOLD"
OPTION_BG="$BLACK$WHITE"
HIGHLIGHT="$REVERSE"
TITLE="$WHITE$BOLD"
NORMAL="$WHITE"

# Значения по умолчанию
TARGET_DISK="/dev/sda"
BOOT_ENABLE="y"
BOOT_SIZE="512M"
ROOT_SIZE="10G"
SWAP_ENABLE="y"
SWAP_SIZE="2G"
FS_TYPE="ext4"
HOSTNAME="pigeonlinux"
GRUB_TARGET="i386-pc"

# Размеры экрана
WIDTH=80
HEIGHT=20
MENU_START=3
CURRENT_SELECTION=1
OPTIONS=9

# Получить размер терминала
get_terminal_size() {
    TERM_WIDTH=$(stty size 2>/dev/null | cut -d' ' -f2)
    TERM_HEIGHT=$(stty size 2>/dev/null | cut -d' ' -f1)
    TERM_WIDTH=${TERM_WIDTH:-80}
    TERM_HEIGHT=${TERM_HEIGHT:-24}
}

# Очистка экрана
clear_screen() {
    printf "\033[2J\033[H"
}

# Нарисовать строку
draw_line() {
    local width=$1
    local char=$2
    local color=$3
    printf "%s" "$color"
    printf "%${width}s" "" | tr ' ' "$char"
    printf "%s" "$RESET"
}

# Нарисовать заголовок
draw_header() {
    local width=$1
    local title="$2"
    
    # Верхняя граница
    printf "%s" "$HEADER_BG"
    printf "┌"
    printf "─%.0s" $(seq 1 $((width-2)))
    printf "┐"
    printf "%s\n" "$RESET"
    
    # Заголовок
    printf "%s" "$HEADER_BG"
    printf "│"
    local padding=$(( (width - 2 - ${#title}) / 2 ))
    printf "%${padding}s" ""
    printf "%s" "$title"
    printf "%$((width - 2 - padding - ${#title}))s" ""
    printf "│"
    printf "%s\n" "$RESET"
    
    # Разделитель
    printf "%s" "$HEADER_BG"
    printf "├"
    printf "─%.0s" $(seq 1 $((width-2)))
    printf "┤"
    printf "%s\n" "$RESET"
}

# Нарисовать нижнюю границу
draw_footer() {
    local width=$1
    
    printf "%s" "$HEADER_BG"
    printf "└"
    printf "─%.0s" $(seq 1 $((width-2)))
    printf "┘"
    printf "%s\n" "$RESET"
}

# Нарисовать пункт меню
draw_menu_item() {
    local number=$1
    local text="$2"
    local value="$3"
    local selected=$4
    local width=$5
    
    if [ $selected -eq 1 ]; then
        printf "%s" "$HIGHLIGHT$OPTION_BG"
    else
        printf "%s" "$OPTION_BG"
    fi
    
    printf "│ %d. %-20s %-40s │" "$number" "$text" "$value"
    printf "%s\n" "$RESET"
}

# Показать список дисков
show_disks() {
    clear_screen
    draw_header $WIDTH "Available Disks"
    
    printf "%s" "$OPTION_BG"
    printf "│ %-10s %-10s %-10s %-20s │\n" "DEVICE" "SIZE" "TYPE" "MOUNTPOINT"
    printf "%s" "$HEADER_BG"
    printf "├"
    printf "─%.0s" $(seq 1 $((WIDTH-2)))
    printf "┤"
    printf "%s\n" "$RESET"
    
    lsblk -d -o NAME,SIZE,TYPE,MOUNTPOINT | grep -v "NAME\|loop" | while read -r line; do
        printf "%s" "$OPTION_BG"
        printf "│ %-47s │\n" "$line"
    done
    
    draw_footer $WIDTH
    echo ""
    printf "%s" "$YELLOW"
    printf "Note: Use full path like /dev/sda, /dev/nvme0n1, etc.\n"
    printf "%s" "$RESET"
    echo ""
    printf "Enter target disk [%s]: " "$TARGET_DISK"
}

# Загрузка конфигурации
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        # Используем source с явным путем
        . "$CONFIG_FILE"
    fi
}

# Сохранение конфигурации
save_config() {
    cat > "$CONFIG_FILE" << EOF
# PigeonLinux Installation Configuration
TARGET_DISK="$TARGET_DISK"
BOOT_ENABLE="$BOOT_ENABLE"
BOOT_SIZE="$BOOT_SIZE"
ROOT_SIZE="$ROOT_SIZE"
SWAP_ENABLE="$SWAP_ENABLE"
SWAP_SIZE="$SWAP_SIZE"
FS_TYPE="$FS_TYPE"
HOSTNAME="$HOSTNAME"
GRUB_TARGET="$GRUB_TARGET"
BOOT_PARTITION="1"
ROOT_PARTITION="2"
SWAP_PARTITION="3"
DESTDIR="/mnt"
EOF
}

# Отрисовка главного меню
draw_main_menu() {
    clear_screen
    draw_header $WIDTH "PigeonLinux Configuration"
    
    draw_menu_item 1 "Target Disk" "$TARGET_DISK" $([ $CURRENT_SELECTION -eq 1 ] && echo 1 || echo 0) $WIDTH
    draw_menu_item 2 "Boot Partition" "$BOOT_ENABLE ($BOOT_SIZE)" $([ $CURRENT_SELECTION -eq 2 ] && echo 1 || echo 0) $WIDTH
    draw_menu_item 3 "Root Partition" "$ROOT_SIZE" $([ $CURRENT_SELECTION -eq 3 ] && echo 1 || echo 0) $WIDTH
    draw_menu_item 4 "Swap Partition" "$SWAP_ENABLE ($SWAP_SIZE)" $([ $CURRENT_SELECTION -eq 4 ] && echo 1 || echo 0) $WIDTH
    draw_menu_item 5 "Filesystem" "$FS_TYPE" $([ $CURRENT_SELECTION -eq 5 ] && echo 1 || echo 0) $WIDTH
    draw_menu_item 6 "Hostname" "$HOSTNAME" $([ $CURRENT_SELECTION -eq 6 ] && echo 1 || echo 0) $WIDTH
    draw_menu_item 7 "GRUB Target" "$GRUB_TARGET" $([ $CURRENT_SELECTION -eq 7 ] && echo 1 || echo 0) $WIDTH
    
    printf "%s" "$HEADER_BG"
    printf "├"
    printf "─%.0s" $(seq 1 $((WIDTH-2)))
    printf "┤"
    printf "%s\n" "$RESET"
    
    draw_menu_item 8 "Save and Exit" "" $([ $CURRENT_SELECTION -eq 8 ] && echo 1 || echo 0) $WIDTH
    draw_menu_item 9 "Exit Without Saving" "" $([ $CURRENT_SELECTION -eq 9 ] && echo 1 || echo 0) $WIDTH
    
    draw_footer $WIDTH
    printf "\n%s" "$YELLOW"
    printf "Use ↑↓ arrows to navigate, Enter to select, q to quit\n"
    printf "%s" "$RESET"
}

# Редактирование параметра
edit_parameter() {
    case $1 in
        1)
            show_disks
            read -r disk
            TARGET_DISK=${disk:-$TARGET_DISK}
            ;;
        2)
            clear_screen
            draw_header $WIDTH "Boot Partition"
            printf "%s" "$OPTION_BG"
            printf "│ Enable boot partition? (y/n) [%s]: " "$BOOT_ENABLE"
            printf "%s\n" "$RESET"
            draw_footer $WIDTH
            printf "\n"
            read -r enable
            BOOT_ENABLE=${enable:-$BOOT_ENABLE}
            if [ "$BOOT_ENABLE" = "y" ]; then
                clear_screen
                draw_header $WIDTH "Boot Partition Size"
                printf "%s" "$OPTION_BG"
                printf "│ Boot partition size (e.g., 512M) [%s]: " "$BOOT_SIZE"
                printf "%s\n" "$RESET"
                draw_footer $WIDTH
                printf "\n"
                read -r size
                BOOT_SIZE=${size:-$BOOT_SIZE}
            fi
            ;;
        3)
            clear_screen
            draw_header $WIDTH "Root Partition Size"
            printf "%s" "$OPTION_BG"
            printf "│ Root partition size (e.g., 10G) [%s]: " "$ROOT_SIZE"
            printf "%s\n" "$RESET"
            draw_footer $WIDTH
            printf "\n"
            read -r size
            ROOT_SIZE=${size:-$ROOT_SIZE}
            ;;
        4)
            clear_screen
            draw_header $WIDTH "Swap Partition"
            printf "%s" "$OPTION_BG"
            printf "│ Enable swap partition? (y/n) [%s]: " "$SWAP_ENABLE"
            printf "%s\n" "$RESET"
            draw_footer $WIDTH
            printf "\n"
            read -r enable
            SWAP_ENABLE=${enable:-$SWAP_ENABLE}
            if [ "$SWAP_ENABLE" = "y" ]; then
                clear_screen
                draw_header $WIDTH "Swap Partition Size"
                printf "%s" "$OPTION_BG"
                printf "│ Swap partition size (e.g., 2G) [%s]: " "$SWAP_SIZE"
                printf "%s\n" "$RESET"
                draw_footer $WIDTH
                printf "\n"
                read -r size
                SWAP_SIZE=${size:-$SWAP_SIZE}
            fi
            ;;
        5)
            clear_screen
            draw_header $WIDTH "Filesystem Type"
            printf "%s" "$OPTION_BG"
            printf "│ Select filesystem:                          │\n"
            printf "│ 1) ext4 (recommended) %s│\n" "$([ "$FS_TYPE" = "ext4" ] && echo "←" || echo "  ")"
            printf "│ 2) ext3 %s│\n" "$([ "$FS_TYPE" = "ext3" ] && echo "←" || echo "  ")"
            printf "│ 3) btrfs %s│\n" "$([ "$FS_TYPE" = "btrfs" ] && echo "←" || echo "  ")"
            printf "│ 4) xfs %s│\n" "$([ "$FS_TYPE" = "xfs" ] && echo "←" || echo "  ")"
            printf "%s\n" "$RESET"
            draw_footer $WIDTH
            printf "\n"
            printf "Choice [1-4]: "
            read -r choice
            case $choice in
                2) FS_TYPE="ext3" ;;
                3) FS_TYPE="btrfs" ;;
                4) FS_TYPE="xfs" ;;
                *) FS_TYPE="ext4" ;;
            esac
            ;;
        6)
            clear_screen
            draw_header $WIDTH "Hostname"
            printf "%s" "$OPTION_BG"
            printf "│ Enter hostname [%s]: " "$HOSTNAME"
            printf "%s\n" "$RESET"
            draw_footer $WIDTH
            printf "\n"
            read -r host
            HOSTNAME=${host:-$HOSTNAME}
            ;;
        7)
            clear_screen
            draw_header $WIDTH "GRUB Target"
            printf "%s" "$OPTION_BG"
            printf "│ Select GRUB target:                         │\n"
            printf "│ 1) i386-pc (BIOS) %s│\n" "$([ "$GRUB_TARGET" = "i386-pc" ] && echo "←" || echo "  ")"
            printf "│ 2) x86_64-efi (UEFI) %s│\n" "$([ "$GRUB_TARGET" = "x86_64-efi" ] && echo "←" || echo "  ")"
            printf "│ 3) i386-efi (UEFI 32-bit) %s│\n" "$([ "$GRUB_TARGET" = "i386-efi" ] && echo "←" || echo "  ")"
            printf "%s\n" "$RESET"
            draw_footer $WIDTH
            printf "\n"
            printf "Choice [1-3]: "
            read -r choice
            case $choice in
                2) GRUB_TARGET="x86_64-efi" ;;
                3) GRUB_TARGET="i386-efi" ;;
                *) GRUB_TARGET="i386-pc" ;;
            esac
            ;;
    esac
}

# Главная функция
main() {
    # Проверка на поддержку цветов
    if [ -t 1 ]; then
        load_config
        get_terminal_size
        
        while true; do
            draw_main_menu
            
            # Чтение клавиш
            read -rsn1 key
            case "$key" in
                $'\x1b') # ESC sequence
                    read -rsn2 -t 0.1 key2
                    case "$key2" in
                        '[A') # Up arrow
                            CURRENT_SELECTION=$((CURRENT_SELECTION > 1 ? CURRENT_SELECTION - 1 : OPTIONS))
                            ;;
                        '[B') # Down arrow
                            CURRENT_SELECTION=$((CURRENT_SELECTION < OPTIONS ? CURRENT_SELECTION + 1 : 1))
                            ;;
                    esac
                    ;;
                '') # Enter
                    case $CURRENT_SELECTION in
                        1|2|3|4|5|6|7)
                            edit_parameter $CURRENT_SELECTION
                            ;;
                        8)
                            save_config
                            clear_screen
                            printf "%s" "$GREEN"
                            printf "Configuration saved to %s\n" "$CONFIG_FILE"
                            printf "Run 'make cfdisk' to partition disk.\n"
                            printf "%s" "$RESET"
                            exit 0
                            ;;
                        9)
                            clear_screen
                            printf "%s" "$YELLOW"
                            printf "Exiting without saving\n"
                            printf "%s" "$RESET"
                            exit 1
                            ;;
                    esac
                    ;;
                'q')
                    clear_screen
                    printf "%s" "$YELLOW"
                    printf "Exiting without saving\n"
                    printf "%s" "$RESET"
                    exit 1
                    ;;
            esac
        done
    else
        # Fallback для терминалов без цветов
        echo "Please run this script in a terminal that supports colors"
        exit 1
    fi
}

# Запуск из правильной директории
cd "$(dirname "$0")/.." || exit 1
main "$@"
