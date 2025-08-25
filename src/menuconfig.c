#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <dirent.h>
#include <sys/stat.h>
#include <sys/ioctl.h>
#include <termios.h>
#include <signal.h>

#define CONFIG_FILE ".config"
#define MAX_OPTIONS 50
#define MAX_LENGTH 100
#define MAX_CHOICES 10
#define MAX_LINE_LENGTH 256
#define MAX_DISKS 20

// Цвета ANSI
#define COLOR_RESET   "\033[0m"
#define COLOR_RED     "\033[31m"
#define COLOR_GREEN   "\033[32m"
#define COLOR_YELLOW  "\033[33m"
#define COLOR_BLUE    "\033[34m"
#define COLOR_MAGENTA "\033[35m"
#define COLOR_CYAN    "\033[36m"
#define COLOR_WHITE   "\033[37m"
#define COLOR_BOLD    "\033[1m"
#define COLOR_REVERSE "\033[7m"

typedef struct {
    char name[MAX_LENGTH];
    char value[MAX_LENGTH];
    char description[MAX_LENGTH];
    int type; // 0: string, 1: bool, 2: choice, 3: disk
    char choices[MAX_CHOICES][MAX_LENGTH];
    int choice_count;
} ConfigOption;

struct termios original_termios;

ConfigOption options[MAX_OPTIONS];
char available_disks[MAX_DISKS][MAX_LENGTH];
int option_count = 0;
int disk_count = 0;
int current_selection = 0;
int terminal_width = 80;
int terminal_height = 24;

void handle_signal(int sig) {
    restore_terminal_state();
    exit(0);
}

void clear_screen() {
    // Вместо полной очистки, просто перемещаем курсор
    printf("\033[H"); // Курсор в начало
    // Не используем "\033[2J" чтобы сохранить историю
}

void save_terminal_state() {
    tcgetattr(STDIN_FILENO, &original_termios);
}

void restore_terminal_state() {
    tcsetattr(STDIN_FILENO, TCSANOW, &original_termios);
    printf("\033[?25h"); // Показываем курсор
}

// Получение размера терминала
void get_terminal_size() {
    struct winsize w;
    if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &w) == 0) {
        terminal_width = w.ws_col;
        terminal_height = w.ws_row;
    }
}

// Центрирование текста
void center_text(const char *text) {
    int padding = (terminal_width - strlen(text)) / 2;
    if (padding < 0) padding = 0;
    printf("%*s%s%*s\n", padding, "", text, padding, "");
}

void draw_line(char ch, int length) {
    for (int i = 0; i < length; i++) {
        putchar(ch);
    }
    printf("\n");
}

void draw_boxed_text(const char *text) {
    int text_len = strlen(text);
    int box_width = text_len + 4;
    int padding = (terminal_width - box_width) / 2;
    
    if (padding < 0) padding = 0;
    
    // Верхняя граница
    printf("%*s+", padding, "");
    for (int i = 0; i < box_width - 2; i++) putchar('-');
    printf("+\n");
    
    // Текст
    printf("%*s| %s%s%s |\n", padding, "", COLOR_BOLD COLOR_CYAN, text, COLOR_RESET);
    
    // Нижняя граница
    printf("%*s+", padding, "");
    for (int i = 0; i < box_width - 2; i++) putchar('-');
    printf("+\n");
}

void scan_disks() {
    disk_count = 0;
    DIR *dir = opendir("/dev");
    if (dir) {
        struct dirent *entry;
        while ((entry = readdir(dir)) != NULL && disk_count < MAX_DISKS) {
            if (strncmp(entry->d_name, "sd", 2) == 0 || 
                strncmp(entry->d_name, "hd", 2) == 0 ||
                strncmp(entry->d_name, "nvme", 4) == 0 ||
                strncmp(entry->d_name, "vd", 2) == 0) {
                
                char path[MAX_LENGTH];
                snprintf(path, MAX_LENGTH, "/dev/%s", entry->d_name);
                
                struct stat st;
                if (stat(path, &st) == 0 && S_ISBLK(st.st_mode)) {
                    strncpy(available_disks[disk_count], path, MAX_LENGTH);
                    disk_count++;
                }
            }
        }
        closedir(dir);
    }
    
    if (disk_count == 0) {
        strcpy(available_disks[disk_count++], "/dev/sda");
        strcpy(available_disks[disk_count++], "/dev/sdb");
        strcpy(available_disks[disk_count++], "/dev/nvme0n1");
    }
}

int parse_type(const char *type_str) {
    if (strcmp(type_str, "string") == 0) return 0;
    if (strcmp(type_str, "bool") == 0) return 1;
    if (strcmp(type_str, "choice") == 0) return 2;
    if (strcmp(type_str, "disk") == 0) return 3;
    return 0;
}

void load_menu_config(const char *filename) {
    FILE *file = fopen(filename, "r");
    if (!file) {
        return;
    }
    
    char line[MAX_LINE_LENGTH];
    while (fgets(line, sizeof(line), file)) {
        if (line[0] == '#' || line[0] == '\n') continue;
        
        line[strcspn(line, "\n")] = 0;
        
        char *parts[6];
        char *token = strtok(line, "|");
        int part_count = 0;
        
        while (token && part_count < 6) {
            parts[part_count++] = token;
            token = strtok(NULL, "|");
        }
        
        if (part_count >= 4) {
            strncpy(options[option_count].name, parts[0], MAX_LENGTH);
            strncpy(options[option_count].value, parts[1], MAX_LENGTH);
            strncpy(options[option_count].description, parts[2], MAX_LENGTH);
            options[option_count].type = parse_type(parts[3]);
            
            if (part_count >= 5 && strlen(parts[4]) > 0) {
                char *choice_token = strtok(parts[4], ",");
                options[option_count].choice_count = 0;
                while (choice_token && options[option_count].choice_count < MAX_CHOICES) {
                    strncpy(options[option_count].choices[options[option_count].choice_count], 
                           choice_token, MAX_LENGTH);
                    options[option_count].choice_count++;
                    choice_token = strtok(NULL, ",");
                }
            }
            option_count++;
        }
    }
    fclose(file);
}

void load_config() {
    FILE *file = fopen(CONFIG_FILE, "r");
    if (file) {
        char line[MAX_LINE_LENGTH];
        while (fgets(line, sizeof(line), file)) {
            if (line[0] == '#' || line[0] == '\n') continue;
            
            char name[MAX_LENGTH], value[MAX_LENGTH];
            if (sscanf(line, "%[^=]=%s", name, value) == 2) {
                if (value[0] == '"' && value[strlen(value)-1] == '"') {
                    memmove(value, value+1, strlen(value)-2);
                    value[strlen(value)-2] = '\0';
                }
                
                for (int i = 0; i < option_count; i++) {
                    if (strcmp(options[i].name, name) == 0) {
                        strncpy(options[i].value, value, MAX_LENGTH);
                        break;
                    }
                }
            }
        }
        fclose(file);
    }
}

void save_config() {
    FILE *file = fopen(CONFIG_FILE, "w");
    if (file) {
        fprintf(file, "# PigeonLinux Installation Configuration\n");
        fprintf(file, "# Generated by menuconfig\n\n");
        
        for (int i = 0; i < option_count; i++) {
            fprintf(file, "%s=\"%s\"\n", options[i].name, options[i].value);
        }
        
        fclose(file);
    }
}

void show_disks_dialog() {
    printf("\033[2J\033[H"); // Очищаем только для диалога
    draw_boxed_text("SELECT DISK");
    printf("\n");
    
    scan_disks();
    
    int selected = 0;
    for (int i = 0; i < disk_count; i++) {
        if (strcmp(available_disks[i], options[0].value) == 0) {
            selected = i;
            break;
        }
    }
    
    printf("%sUse arrow keys to select, Enter to confirm%s\n\n", COLOR_YELLOW, COLOR_RESET);
    
    int ch;
    do {
        // Перемещаем курсор вверх для перерисовки
        printf("\033[%dA", disk_count + 2);
        
        for (int i = 0; i < disk_count; i++) {
            if (i == selected) {
                printf("%s%s> %s%s%s\n", COLOR_REVERSE, COLOR_GREEN, COLOR_WHITE, 
                       available_disks[i], COLOR_RESET);
            } else {
                printf("  %s\n", available_disks[i]);
            }
        }
        printf("\n");
        
        ch = getchar();
        if (ch == 27) { // Escape sequence
            getchar(); // Skip [
            ch = getchar(); // Get arrow key
        }
        
        switch (ch) {
            case 'A': // Up arrow
                if (selected > 0) selected--;
                break;
            case 'B': // Down arrow
                if (selected < disk_count - 1) selected++;
                break;
        }
    } while (ch != '\n' && ch != 'q');
    
    if (ch == '\n') {
        strncpy(options[0].value, available_disks[selected], MAX_LENGTH);
    }
    
    // После диалога не очищаем экран полностью
}

void show_help() {
    printf("\033[2J\033[H"); // Очищаем только для помощи
    draw_boxed_text("HELP");
    printf("\n");
    
    printf("%sNavigation:%s\n", COLOR_BOLD, COLOR_RESET);
    printf("  ↑↓ arrows - Move selection\n");
    printf("  Enter     - Edit value\n");
    printf("  Y/N       - Toggle boolean options\n");
    printf("  Space     - Toggle boolean options\n");
    printf("  S         - Save configuration\n");
    printf("  Q         - Quit without saving\n");
    printf("  H         - This help\n");
    printf("  D         - Show disks\n");
    
    printf("\n%sPress any key to continue...%s", COLOR_YELLOW, COLOR_RESET);
    getchar();
    
    // После помощи не очищаем экран полностью
}

void draw_interface() {
    printf("\033[H"); // Курсор в начало
    get_terminal_size();
    
    // Header - очищаем и рисуем заново
    printf("\033[K"); // Очищаем первую строку
    printf("%s", COLOR_BLUE COLOR_BOLD);
    center_text("+========================================+");
    printf("\033[K"); // Очищаем вторую строку
    center_text("|        PIGEONLINUX CONFIGURATION       |");
    printf("\033[K"); // Очищаем третью строку
    center_text("+========================================+");
    printf("%s", COLOR_RESET);
    printf("\033[K"); // Очищаем пустую строку после заголовка
    printf("\n");

    // Options - очищаем и рисуем заново каждую строку
    for (int i = 0; i < option_count; i++) {
        int padding = (terminal_width - 60) / 2;
        if (padding < 0) padding = 0;
        
        printf("\033[K"); // Очищаем строку перед выводом
        printf("%*s", padding, "");
        
        if (i == current_selection) {
            printf("%s%s>%s ", COLOR_GREEN COLOR_BOLD, COLOR_REVERSE, COLOR_RESET);
        } else {
            printf("  ");
        }
        
        printf("%-20s ", options[i].name);
        
        if (options[i].type == 1) { // Boolean
            if (strcmp(options[i].value, "y") == 0) {
                printf("%s[✓]%s", COLOR_GREEN, COLOR_RESET);
            } else {
                printf("%s[ ]%s", COLOR_RED, COLOR_RESET);
            }
        } else {
            printf("%s<%s>%s", COLOR_CYAN, options[i].value, COLOR_RESET);
        }
        
        printf("  %s%s%s\n", COLOR_YELLOW, options[i].description, COLOR_RESET);
    }
    
    // Очищаем оставшееся пространство
    int lines_used = option_count + 5; // заголовок + опции + пустая строка
    for (int i = lines_used; i < terminal_height - 2; i++) {
        printf("\033[K\n"); // Очищаем строку и переходим на новую
    }
    
    // Footer - очищаем и рисуем заново
    printf("\033[K"); // Очищаем строку перед футером
    center_text("↑↓:Navigate  Enter:Edit  Y/N:Toggle  S:Save  Q:Quit  H:Help  D:Disks");
    
    // Перемещаем курсор обратно к выбранной опции
    printf("\033[%dA", terminal_height - current_selection - 7);
}

int main(int argc, char *argv[]) {

    signal(SIGINT, handle_signal);
    signal(SIGTERM, handle_signal);

    const char *menu_conf = "menu.conf";
    if (argc > 1) {
        menu_conf = argv[1];
    }
    
    // Сохраняем оригинальное состояние терминала
    save_terminal_state();
    
    // Настройка терминала
    struct termios newt;
    newt = original_termios;
    newt.c_lflag &= ~(ICANON | ECHO);
    tcsetattr(STDIN_FILENO, TCSANOW, &newt);
    printf("\033[?25l"); // Скрываем курсор
    
    scan_disks();
    load_menu_config(menu_conf);
    
    // Опции по умолчанию
    if (option_count == 0) {
        strcpy(options[option_count].name, "TARGET_DISK");
        strcpy(options[option_count].value, "/dev/sda");
        strcpy(options[option_count].description, "Target disk device");
        options[option_count].type = 3;
        option_count++;
        
        strcpy(options[option_count].name, "BOOT_ENABLE");
        strcpy(options[option_count].value, "y");
        strcpy(options[option_count].description, "Enable boot partition");
        options[option_count].type = 1;
        option_count++;
    }
    
    load_config();
    
    int ch;
    while (1) {
        draw_interface();
        ch = getchar();
        
        if (ch == 27) { // Escape sequence
            getchar(); // Skip [
            ch = getchar(); // Get arrow key
        }
        
        switch (ch) {
            case 'A': // Up arrow
                if (current_selection > 0) {
                    current_selection--;
                }
                break;
                
            case 'B': // Down arrow
                if (current_selection < option_count - 1) {
                    current_selection++;
                }
                break;
                
            case '\n': // Enter
                if (options[current_selection].type == 3) { // Disk type
                    show_disks_dialog();
                }
                break;
                
            case 'y': case 'Y':
                if (options[current_selection].type == 1) {
                    strcpy(options[current_selection].value, "y");
                }
                break;
                
            case 'n': case 'N':
                if (options[current_selection].type == 1) {
                    strcpy(options[current_selection].value, "n");
                }
                break;
                
            case ' ': // Space
                if (options[current_selection].type == 1) {
                    if (strcmp(options[current_selection].value, "y") == 0) {
                        strcpy(options[current_selection].value, "n");
                    } else {
                        strcpy(options[current_selection].value, "y");
                    }
                }
                break;
                
            case 's': case 'S':
                save_config();
                clear_screen();
                center_text("Configuration saved!");
                printf("\n");
                center_text("Press any key to continue...");
                getchar();
                break;
                
            case 'd': case 'D':
                show_disks_dialog();
                break;
                
            case 'h': case 'H':
                show_help();
                break;
                
            case 'q': case 'Q':
                // Восстанавливаем терминал перед выходом
                restore_terminal_state();
                return 0;
        }
    }
    
    // Восстанавливаем терминал (на всякий случай)
    restore_terminal_state();
    return 0;
}
