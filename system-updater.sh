#!/bin/bash

# Ubuntu System Updater v2.0
# Расширенное приложение для управления обновлениями системы

VERSION="2.1.0"
CONFIG_DIR="$HOME/.config/aupdate"
LOG_FILE="$CONFIG_DIR/update.log"
BACKUP_DIR="$CONFIG_DIR/backups"
HISTORY_FILE="$CONFIG_DIR/history.log"
CRON_FILE="$CONFIG_DIR/auto_update_cron"
AUTO_UPDATE_CONFIG="$CONFIG_DIR/auto_update.conf"
SCRIPT_PATH="/usr/local/bin/aupdate"
GITHUB_REPO="https://github.com/Fixcat/UbuntuAutoUpdater.git"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Создание директорий
init_dirs() {
    mkdir -p "$CONFIG_DIR" "$BACKUP_DIR"
    touch "$LOG_FILE" "$HISTORY_FILE"
}

# Логирование
log_action() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$HISTORY_FILE"
}

# Проверка прав root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Ошибка: Требуются права root${NC}"
        echo "Запустите: sudo aupdate"
        exit 1
    fi
}

# Проверка интернет-соединения
check_internet() {
    if ! ping -c 1 8.8.8.8 &> /dev/null; then
        echo -e "${RED}✗ Нет подключения к интернету${NC}"
        return 1
    fi
    return 0
}

# Получение информации о системе
get_system_info() {
    OS_VERSION=$(lsb_release -d | cut -f2)
    KERNEL=$(uname -r)
    ARCH=$(uname -m)
    UPTIME=$(uptime -p)
}

# Сканирование системы
scan_updates() {
    echo -e "${BLUE}=== Сканирование системы ===${NC}"
    log_action "Начато сканирование обновлений"
    
    if ! check_internet; then
        return 1
    fi
    
    echo -e "${YELLOW}Обновление списка пакетов...${NC}"
    apt-get update > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Список пакетов обновлен${NC}"
        log_action "Список пакетов успешно обновлен"
    else
        echo -e "${RED}✗ Ошибка при обновлении${NC}"
        log_action "ОШИБКА: Не удалось обновить список пакетов"
        return 1
    fi
    
    UPDATES=$(apt list --upgradable 2>/dev/null | grep -v "Listing")
    UPDATE_COUNT=$(echo "$UPDATES" | grep -c "upgradable")
    
    if [ "$UPDATE_COUNT" -eq 0 ]; then
        echo -e "${GREEN}✓ Система полностью обновлена${NC}"
        log_action "Обновления не найдены"
        return 2
    fi
    
    echo -e "${GREEN}Найдено обновлений: $UPDATE_COUNT${NC}"
    log_action "Найдено обновлений: $UPDATE_COUNT"
    return 0
}

# Показать обновления
show_updates() {
    echo -e "${BLUE}=== Доступные обновления ===${NC}"
    echo ""
    
    apt list --upgradable 2>/dev/null | grep "upgradable" | while read -r line; do
        PACKAGE=$(echo "$line" | cut -d'/' -f1)
        VERSION=$(echo "$line" | grep -oP '\d+[^\s]+' | head -1)
        echo -e "${YELLOW}•${NC} $PACKAGE ${GREEN}→${NC} $VERSION"
    done
    echo ""
}

# Обновить все пакеты
update_all() {
    echo -e "${BLUE}=== Обновление всех компонентов ===${NC}"
    read -p "Вы уверены? (y/n): " confirm
    
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo -e "${YELLOW}Отменено${NC}"
        return
    fi
    
    log_action "Начато обновление всех пакетов"
    echo -e "${YELLOW}Обновление...${NC}"
    apt-get upgrade -y
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Обновлено успешно${NC}"
        log_action "Все пакеты успешно обновлены"
    else
        echo -e "${RED}✗ Ошибка${NC}"
        log_action "ОШИБКА: Не удалось обновить пакеты"
    fi
}

# Обновить конкретный пакет
update_specific() {
    echo -e "${BLUE}=== Обновление пакета ===${NC}"
    read -p "Имя пакета: " package_name
    
    if [ -z "$package_name" ]; then
        echo -e "${RED}Имя не может быть пустым${NC}"
        return
    fi
    
    if apt list --upgradable 2>/dev/null | grep -q "^$package_name/"; then
        log_action "Обновление пакета: $package_name"
        apt-get install --only-upgrade "$package_name" -y
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Обновлено: $package_name${NC}"
            log_action "Пакет $package_name успешно обновлен"
        else
            echo -e "${RED}✗ Ошибка${NC}"
            log_action "ОШИБКА: Не удалось обновить $package_name"
        fi
    else
        echo -e "${YELLOW}Обновление не найдено${NC}"
    fi
}

# Автоочистка
auto_clean() {
    echo -e "${BLUE}=== Автоочистка системы ===${NC}"
    log_action "Начата автоочистка"
    
    echo -e "${YELLOW}Удаление ненужных пакетов...${NC}"
    apt-get autoremove -y > /dev/null 2>&1
    echo -e "${GREEN}✓ Autoremove выполнен${NC}"
    
    echo -e "${YELLOW}Очистка кэша...${NC}"
    apt-get autoclean -y > /dev/null 2>&1
    echo -e "${GREEN}✓ Autoclean выполнен${NC}"
    
    echo -e "${YELLOW}Очистка apt кэша...${NC}"
    apt-get clean > /dev/null 2>&1
    echo -e "${GREEN}✓ Clean выполнен${NC}"
    
    log_action "Автоочистка завершена"
}

# Показать информацию о системе
show_system_info() {
    get_system_info
    echo -e "${BLUE}=== Информация о системе ===${NC}"
    echo -e "${CYAN}ОС:${NC} $OS_VERSION"
    echo -e "${CYAN}Ядро:${NC} $KERNEL"
    echo -e "${CYAN}Архитектура:${NC} $ARCH"
    echo -e "${CYAN}Uptime:${NC} $UPTIME"
    echo -e "${CYAN}Версия aupdate:${NC} $VERSION"
    echo ""
}

# Показать статистику дискового пространства
show_disk_usage() {
    echo -e "${BLUE}=== Использование диска ===${NC}"
    df -h / | tail -1 | awk '{print "Использовано: "$3" из "$2" ("$5")"}'
    echo ""
}

# Показать историю обновлений
show_history() {
    echo -e "${BLUE}=== История обновлений ===${NC}"
    if [ -f "$HISTORY_FILE" ]; then
        tail -20 "$HISTORY_FILE"
    else
        echo -e "${YELLOW}История пуста${NC}"
    fi
    echo ""
}

# Поиск пакета
search_package() {
    echo -e "${BLUE}=== Поиск пакета ===${NC}"
    read -p "Введите имя пакета: " search_term
    
    if [ -z "$search_term" ]; then
        echo -e "${RED}Имя не может быть пустым${NC}"
        return
    fi
    
    echo -e "${YELLOW}Поиск...${NC}"
    apt-cache search "$search_term" | head -20
    echo ""
}

# Показать информацию о пакете
show_package_info() {
    echo -e "${BLUE}=== Информация о пакете ===${NC}"
    read -p "Введите имя пакета: " package_name
    
    if [ -z "$package_name" ]; then
        echo -e "${RED}Имя не может быть пустым${NC}"
        return
    fi
    
    apt-cache show "$package_name" 2>/dev/null || echo -e "${RED}Пакет не найден${NC}"
    echo ""
}

# Установить новый пакет
install_package() {
    echo -e "${BLUE}=== Установка пакета ===${NC}"
    read -p "Введите имя пакета: " package_name
    
    if [ -z "$package_name" ]; then
        echo -e "${RED}Имя не может быть пустым${NC}"
        return
    fi
    
    log_action "Установка пакета: $package_name"
    apt-get install "$package_name" -y
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Установлено: $package_name${NC}"
        log_action "Пакет $package_name успешно установлен"
    else
        echo -e "${RED}✗ Ошибка установки${NC}"
        log_action "ОШИБКА: Не удалось установить $package_name"
    fi
}

# Удалить пакет
remove_package() {
    echo -e "${BLUE}=== Удаление пакета ===${NC}"
    read -p "Введите имя пакета: " package_name
    
    if [ -z "$package_name" ]; then
        echo -e "${RED}Имя не может быть пустым${NC}"
        return
    fi
    
    read -p "Удалить $package_name? (y/n): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo -e "${YELLOW}Отменено${NC}"
        return
    fi
    
    log_action "Удаление пакета: $package_name"
    apt-get remove "$package_name" -y
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Удалено: $package_name${NC}"
        log_action "Пакет $package_name успешно удален"
    else
        echo -e "${RED}✗ Ошибка${NC}"
        log_action "ОШИБКА: Не удалось удалить $package_name"
    fi
}

# Полное обновление (dist-upgrade)
dist_upgrade() {
    echo -e "${BLUE}=== Полное обновление системы ===${NC}"
    echo -e "${YELLOW}Это обновит систему с разрешением зависимостей${NC}"
    read -p "Продолжить? (y/n): " confirm
    
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo -e "${YELLOW}Отменено${NC}"
        return
    fi
    
    log_action "Начато dist-upgrade"
    apt-get dist-upgrade -y
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Система обновлена${NC}"
        log_action "Dist-upgrade успешно выполнен"
    else
        echo -e "${RED}✗ Ошибка${NC}"
        log_action "ОШИБКА: Dist-upgrade не выполнен"
    fi
}

# Исправить сломанные зависимости
fix_broken() {
    echo -e "${BLUE}=== Исправление зависимостей ===${NC}"
    log_action "Исправление сломанных зависимостей"
    
    apt-get install -f -y
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Зависимости исправлены${NC}"
        log_action "Зависимости успешно исправлены"
    else
        echo -e "${RED}✗ Ошибка${NC}"
        log_action "ОШИБКА: Не удалось исправить зависимости"
    fi
}

# Показать установленные пакеты
list_installed() {
    echo -e "${BLUE}=== Установленные пакеты ===${NC}"
    read -p "Показать все? (y/n, по умолчанию первые 50): " show_all
    
    if [ "$show_all" = "y" ] || [ "$show_all" = "Y" ]; then
        dpkg -l | grep ^ii
    else
        dpkg -l | grep ^ii | head -50
        echo -e "${YELLOW}Показано первых 50 пакетов${NC}"
    fi
    echo ""
}

# Создать резервную копию списка пакетов
backup_packages() {
    echo -e "${BLUE}=== Резервное копирование ===${NC}"
    BACKUP_FILE="$BACKUP_DIR/packages_$(date +%Y%m%d_%H%M%S).txt"
    
    dpkg --get-selections > "$BACKUP_FILE"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Резервная копия создана${NC}"
        echo -e "${CYAN}Файл: $BACKUP_FILE${NC}"
        log_action "Создана резервная копия: $BACKUP_FILE"
    else
        echo -e "${RED}✗ Ошибка${NC}"
    fi
}

# Восстановить из резервной копии
restore_packages() {
    echo -e "${BLUE}=== Восстановление из резервной копии ===${NC}"
    
    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A $BACKUP_DIR)" ]; then
        echo -e "${RED}Резервные копии не найдены${NC}"
        return
    fi
    
    echo -e "${YELLOW}Доступные резервные копии:${NC}"
    ls -1 "$BACKUP_DIR"
    echo ""
    
    read -p "Введите имя файла: " backup_file
    
    if [ ! -f "$BACKUP_DIR/$backup_file" ]; then
        echo -e "${RED}Файл не найден${NC}"
        return
    fi
    
    dpkg --set-selections < "$BACKUP_DIR/$backup_file"
    apt-get dselect-upgrade -y
    
    echo -e "${GREEN}✓ Восстановление завершено${NC}"
    log_action "Восстановлено из: $backup_file"
}

# Показать размер кэша
show_cache_size() {
    echo -e "${BLUE}=== Размер кэша APT ===${NC}"
    CACHE_SIZE=$(du -sh /var/cache/apt/archives 2>/dev/null | cut -f1)
    echo -e "${CYAN}Размер кэша: $CACHE_SIZE${NC}"
    echo ""
}

# Обновить только безопасные обновления
security_updates() {
    echo -e "${BLUE}=== Обновления безопасности ===${NC}"
    log_action "Установка обновлений безопасности"
    
    apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Обновления безопасности установлены${NC}"
        log_action "Обновления безопасности успешно установлены"
    else
        echo -e "${RED}✗ Ошибка${NC}"
    fi
}

# Проверить целостность пакетов
check_integrity() {
    echo -e "${BLUE}=== Проверка целостности ===${NC}"
    log_action "Проверка целостности пакетов"
    
    dpkg --audit
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Проблем не обнаружено${NC}"
    else
        echo -e "${YELLOW}Обнаружены проблемы${NC}"
    fi
}

# Показать репозитории
show_repositories() {
    echo -e "${BLUE}=== Активные репозитории ===${NC}"
    grep -r --include '*.list' '^deb ' /etc/apt/sources.list /etc/apt/sources.list.d/
    echo ""
}

# Экспорт логов
export_logs() {
    echo -e "${BLUE}=== Экспорт логов ===${NC}"
    EXPORT_FILE="$HOME/aupdate_logs_$(date +%Y%m%d_%H%M%S).txt"
    
    cp "$LOG_FILE" "$EXPORT_FILE"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Логи экспортированы${NC}"
        echo -e "${CYAN}Файл: $EXPORT_FILE${NC}"
    else
        echo -e "${RED}✗ Ошибка${NC}"
    fi
}

# Очистить логи
clear_logs() {
    echo -e "${BLUE}=== Очистка логов ===${NC}"
    read -p "Очистить все логи? (y/n): " confirm
    
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        > "$LOG_FILE"
        > "$HISTORY_FILE"
        echo -e "${GREEN}✓ Логи очищены${NC}"
        log_action "Логи очищены пользователем"
    else
        echo -e "${YELLOW}Отменено${NC}"
    fi
}

# Показать обновления ядра
show_kernel_updates() {
    echo -e "${BLUE}=== Обновления ядра ===${NC}"
    apt list --upgradable 2>/dev/null | grep linux-image
    echo ""
}

# Удалить старые ядра
remove_old_kernels() {
    echo -e "${BLUE}=== Удаление старых ядер ===${NC}"
    CURRENT_KERNEL=$(uname -r)
    echo -e "${CYAN}Текущее ядро: $CURRENT_KERNEL${NC}"
    
    read -p "Удалить старые ядра? (y/n): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo -e "${YELLOW}Отменено${NC}"
        return
    fi
    
    apt-get autoremove --purge -y
    echo -e "${GREEN}✓ Старые ядра удалены${NC}"
    log_action "Удалены старые ядра"
}

# Проверить наличие перезагрузки
check_reboot_required() {
    if [ -f /var/run/reboot-required ]; then
        echo -e "${YELLOW}⚠ Требуется перезагрузка системы${NC}"
        cat /var/run/reboot-required.pkgs 2>/dev/null
    else
        echo -e "${GREEN}✓ Перезагрузка не требуется${NC}"
    fi
}

# Показать статистику обновлений
show_update_stats() {
    echo -e "${BLUE}=== Статистика обновлений ===${NC}"
    
    if [ -f "$HISTORY_FILE" ]; then
        TOTAL_UPDATES=$(grep -c "успешно обновлен" "$HISTORY_FILE")
        TOTAL_INSTALLS=$(grep -c "успешно установлен" "$HISTORY_FILE")
        TOTAL_REMOVES=$(grep -c "успешно удален" "$HISTORY_FILE")
        
        echo -e "${CYAN}Всего обновлений: $TOTAL_UPDATES${NC}"
        echo -e "${CYAN}Всего установок: $TOTAL_INSTALLS${NC}"
        echo -e "${CYAN}Всего удалений: $TOTAL_REMOVES${NC}"
    else
        echo -e "${YELLOW}Статистика недоступна${NC}"
    fi
    echo ""
}

# Тест скорости репозиториев
test_repo_speed() {
    echo -e "${BLUE}=== Тест скорости репозиториев ===${NC}"
    echo -e "${YELLOW}Тестирование...${NC}"
    
    time apt-get update > /dev/null 2>&1
    echo -e "${GREEN}✓ Тест завершен${NC}"
}

# Показать зависимости пакета
show_dependencies() {
    echo -e "${BLUE}=== Зависимости пакета ===${NC}"
    read -p "Введите имя пакета: " package_name
    
    if [ -z "$package_name" ]; then
        echo -e "${RED}Имя не может быть пустым${NC}"
        return
    fi
    
    apt-cache depends "$package_name" 2>/dev/null || echo -e "${RED}Пакет не найден${NC}"
    echo ""
}

# Показать обратные зависимости
show_reverse_dependencies() {
    echo -e "${BLUE}=== Обратные зависимости ===${NC}"
    read -p "Введите имя пакета: " package_name
    
    if [ -z "$package_name" ]; then
        echo -e "${RED}Имя не может быть пустым${NC}"
        return
    fi
    
    apt-cache rdepends "$package_name" 2>/dev/null || echo -e "${RED}Пакет не найден${NC}"
    echo ""
}

# Симуляция обновления
simulate_update() {
    echo -e "${BLUE}=== Симуляция обновления ===${NC}"
    echo -e "${YELLOW}Симуляция (без реальных изменений)...${NC}"
    
    apt-get upgrade -s
    echo ""
}

# Показать файлы пакета
show_package_files() {
    echo -e "${BLUE}=== Файлы пакета ===${NC}"
    read -p "Введите имя пакета: " package_name
    
    if [ -z "$package_name" ]; then
        echo -e "${RED}Имя не может быть пустым${NC}"
        return
    fi
    
    dpkg -L "$package_name" 2>/dev/null || echo -e "${RED}Пакет не установлен${NC}"
    echo ""
}

# Найти пакет по файлу
find_package_by_file() {
    echo -e "${BLUE}=== Поиск пакета по файлу ===${NC}"
    read -p "Введите путь к файлу: " file_path
    
    if [ -z "$file_path" ]; then
        echo -e "${RED}Путь не может быть пустым${NC}"
        return
    fi
    
    dpkg -S "$file_path" 2>/dev/null || echo -e "${RED}Файл не принадлежит ни одному пакету${NC}"
    echo ""
}

# Проверить обновления для конкретного пакета
check_package_update() {
    echo -e "${BLUE}=== Проверка обновления пакета ===${NC}"
    read -p "Введите имя пакета: " package_name
    
    if [ -z "$package_name" ]; then
        echo -e "${RED}Имя не может быть пустым${NC}"
        return
    fi
    
    apt list --upgradable 2>/dev/null | grep "^$package_name/" || echo -e "${GREEN}Обновление не требуется${NC}"
    echo ""
}

# Показать changelog пакета
show_changelog() {
    echo -e "${BLUE}=== Changelog пакета ===${NC}"
    read -p "Введите имя пакета: " package_name
    
    if [ -z "$package_name" ]; then
        echo -e "${RED}Имя не может быть пустым${NC}"
        return
    fi
    
    apt-get changelog "$package_name" 2>/dev/null | head -50 || echo -e "${RED}Changelog недоступен${NC}"
    echo ""
}

# Загрузить пакет без установки
download_package() {
    echo -e "${BLUE}=== Загрузка пакета ===${NC}"
    read -p "Введите имя пакета: " package_name
    
    if [ -z "$package_name" ]; then
        echo -e "${RED}Имя не может быть пустым${NC}"
        return
    fi
    
    apt-get download "$package_name"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Пакет загружен${NC}"
    else
        echo -e "${RED}✗ Ошибка загрузки${NC}"
    fi
}

# Переустановить пакет
reinstall_package() {
    echo -e "${BLUE}=== Переустановка пакета ===${NC}"
    read -p "Введите имя пакета: " package_name
    
    if [ -z "$package_name" ]; then
        echo -e "${RED}Имя не может быть пустым${NC}"
        return
    fi
    
    apt-get install --reinstall "$package_name" -y
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Пакет переустановлен${NC}"
        log_action "Переустановлен пакет: $package_name"
    else
        echo -e "${RED}✗ Ошибка${NC}"
    fi
}

# Показать удерживаемые пакеты
show_held_packages() {
    echo -e "${BLUE}=== Удерживаемые пакеты ===${NC}"
    dpkg --get-selections | grep hold
    echo ""
}

# Удержать пакет
hold_package() {
    echo -e "${BLUE}=== Удержание пакета ===${NC}"
    read -p "Введите имя пакета: " package_name
    
    if [ -z "$package_name" ]; then
        echo -e "${RED}Имя не может быть пустым${NC}"
        return
    fi
    
    apt-mark hold "$package_name"
    echo -e "${GREEN}✓ Пакет удержан${NC}"
    log_action "Удержан пакет: $package_name"
}

# Снять удержание пакета
unhold_package() {
    echo -e "${BLUE}=== Снятие удержания ===${NC}"
    read -p "Введите имя пакета: " package_name
    
    if [ -z "$package_name" ]; then
        echo -e "${RED}Имя не может быть пустым${NC}"
        return
    fi
    
    apt-mark unhold "$package_name"
    echo -e "${GREEN}✓ Удержание снято${NC}"
    log_action "Снято удержание: $package_name"
}

# Показать автоматически установленные пакеты
show_auto_installed() {
    echo -e "${BLUE}=== Автоматически установленные ===${NC}"
    apt-mark showauto | head -50
    echo -e "${YELLOW}Показано первых 50${NC}"
    echo ""
}

# Показать вручную установленные пакеты
show_manual_installed() {
    echo -e "${BLUE}=== Вручную установленные ===${NC}"
    apt-mark showmanual | head -50
    echo -e "${YELLOW}Показано первых 50${NC}"
    echo ""
}

# Проверить наличие PPA
check_ppa() {
    echo -e "${BLUE}=== Проверка PPA ===${NC}"
    
    if [ -d /etc/apt/sources.list.d/ ]; then
        ls -1 /etc/apt/sources.list.d/*.list 2>/dev/null || echo -e "${YELLOW}PPA не найдены${NC}"
    else
        echo -e "${YELLOW}PPA не найдены${NC}"
    fi
    echo ""
}

# Обновить только из определенного репозитория
update_from_repo() {
    echo -e "${BLUE}=== Обновление из репозитория ===${NC}"
    read -p "Введите имя репозитория: " repo_name
    
    if [ -z "$repo_name" ]; then
        echo -e "${RED}Имя не может быть пустым${NC}"
        return
    fi
    
    apt-get update -o Dir::Etc::sourcelist="sources.list.d/$repo_name" -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0"
    echo -e "${GREEN}✓ Обновлено${NC}"
}

# Настроить автообновление
setup_auto_update() {
    echo -e "${BLUE}=== Настройка автообновления ===${NC}"
    echo ""
    echo -e "${YELLOW}Автообновление будет запускаться в фоновом режиме${NC}"
    echo -e "${YELLOW}и обновлять все пакеты системы${NC}"
    echo ""
    
    # Проверка существующего автообновления
    if crontab -l 2>/dev/null | grep -q "aupdate-auto"; then
        echo -e "${YELLOW}⚠ Автообновление уже настроено${NC}"
        read -p "Перенастроить? (y/n): " reconfigure
        if [ "$reconfigure" != "y" ] && [ "$reconfigure" != "Y" ]; then
            return
        fi
    fi
    
    echo "Выберите интервал автообновления:"
    echo "1) Каждые 2 часа"
    echo "2) Каждые 4 часа"
    echo "3) Каждые 6 часов"
    echo "4) Каждые 12 часов"
    echo "5) Каждые 24 часа (раз в день)"
    echo "6) Свой интервал"
    echo ""
    read -p "Выберите (1-6): " interval_choice
    
    case $interval_choice in
        1) CRON_SCHEDULE="0 */2 * * *" ; INTERVAL_DESC="каждые 2 часа" ;;
        2) CRON_SCHEDULE="0 */4 * * *" ; INTERVAL_DESC="каждые 4 часа" ;;
        3) CRON_SCHEDULE="0 */6 * * *" ; INTERVAL_DESC="каждые 6 часов" ;;
        4) CRON_SCHEDULE="0 */12 * * *" ; INTERVAL_DESC="каждые 12 часов" ;;
        5) CRON_SCHEDULE="0 0 * * *" ; INTERVAL_DESC="каждые 24 часа" ;;
        6)
            echo ""
            read -p "Введите интервал в часах: " custom_hours
            if ! [[ "$custom_hours" =~ ^[0-9]+$ ]]; then
                echo -e "${RED}Неверный формат${NC}"
                return
            fi
            CRON_SCHEDULE="0 */$custom_hours * * *"
            INTERVAL_DESC="каждые $custom_hours часов"
            ;;
        *)
            echo -e "${RED}Неверный выбор${NC}"
            return
            ;;
    esac
    
    # Создание скрипта автообновления
    cat > "$CRON_FILE" << 'EOF'
#!/bin/bash
# Автообновление системы
LOG_FILE="$HOME/.config/aupdate/auto_update.log"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Начато автообновление" >> "$LOG_FILE"
apt-get update >> "$LOG_FILE" 2>&1
apt-get upgrade -y >> "$LOG_FILE" 2>&1
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Автообновление завершено" >> "$LOG_FILE"
EOF
    
    chmod +x "$CRON_FILE"
    
    # Добавление в crontab
    (crontab -l 2>/dev/null | grep -v "aupdate-auto"; echo "$CRON_SCHEDULE $CRON_FILE # aupdate-auto") | crontab -
    
    # Сохранение конфигурации
    echo "ENABLED=true" > "$AUTO_UPDATE_CONFIG"
    echo "SCHEDULE=$CRON_SCHEDULE" >> "$AUTO_UPDATE_CONFIG"
    echo "INTERVAL=$INTERVAL_DESC" >> "$AUTO_UPDATE_CONFIG"
    
    echo ""
    echo -e "${GREEN}✓ Автообновление настроено${NC}"
    echo -e "${CYAN}Интервал: $INTERVAL_DESC${NC}"
    echo -e "${CYAN}Расписание: $CRON_SCHEDULE${NC}"
    echo ""
    echo -e "${YELLOW}Логи автообновления: ~/.config/aupdate/auto_update.log${NC}"
    
    log_action "Настроено автообновление: $INTERVAL_DESC"
}

# Отключить автообновление
disable_auto_update() {
    echo -e "${BLUE}=== Отключение автообновления ===${NC}"
    
    # Проверка наличия автообновления
    if ! crontab -l 2>/dev/null | grep -q "aupdate-auto"; then
        echo -e "${YELLOW}Автообновление не настроено${NC}"
        return
    fi
    
    read -p "Отключить автообновление? (y/n): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo -e "${YELLOW}Отменено${NC}"
        return
    fi
    
    # Удаление из crontab
    crontab -l 2>/dev/null | grep -v "aupdate-auto" | crontab -
    
    # Обновление конфигурации
    if [ -f "$AUTO_UPDATE_CONFIG" ]; then
        sed -i 's/ENABLED=true/ENABLED=false/' "$AUTO_UPDATE_CONFIG"
    fi
    
    echo -e "${GREEN}✓ Автообновление отключено${NC}"
    log_action "Автообновление отключено"
}

# Показать статус автообновления
show_auto_update_status() {
    echo -e "${BLUE}=== Статус автообновления ===${NC}"
    
    if crontab -l 2>/dev/null | grep -q "aupdate-auto"; then
        echo -e "${GREEN}✓ Автообновление включено${NC}"
        
        if [ -f "$AUTO_UPDATE_CONFIG" ]; then
            source "$AUTO_UPDATE_CONFIG"
            echo -e "${CYAN}Интервал: $INTERVAL${NC}"
            echo -e "${CYAN}Расписание: $SCHEDULE${NC}"
        fi
        
        # Показать последние записи из лога
        if [ -f "$HOME/.config/aupdate/auto_update.log" ]; then
            echo ""
            echo -e "${YELLOW}Последние записи:${NC}"
            tail -5 "$HOME/.config/aupdate/auto_update.log"
        fi
    else
        echo -e "${RED}✗ Автообновление отключено${NC}"
    fi
    echo ""
}

# Обновить само приложение
update_application() {
    echo -e "${BLUE}=== Обновление приложения ===${NC}"
    echo -e "${YELLOW}Текущая версия: $VERSION${NC}"
    echo ""
    
    # Проверка интернета
    if ! check_internet; then
        return
    fi
    
    echo -e "${YELLOW}Проверка обновлений...${NC}"
    
    # Создание временной директории
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR" || return
    
    # Клонирование репозитория
    echo -e "${YELLOW}Загрузка последней версии...${NC}"
    git clone --depth 1 "$GITHUB_REPO" . > /dev/null 2>&1
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Ошибка загрузки${NC}"
        cd - > /dev/null
        rm -rf "$TEMP_DIR"
        return
    fi
    
    # Проверка версии
    NEW_VERSION=$(grep "^VERSION=" system-updater.sh | cut -d'"' -f2)
    
    if [ -z "$NEW_VERSION" ]; then
        echo -e "${RED}✗ Не удалось определить версию${NC}"
        cd - > /dev/null
        rm -rf "$TEMP_DIR"
        return
    fi
    
    echo -e "${CYAN}Доступная версия: $NEW_VERSION${NC}"
    
    if [ "$VERSION" = "$NEW_VERSION" ]; then
        echo -e "${GREEN}✓ У вас установлена последняя версия${NC}"
        cd - > /dev/null
        rm -rf "$TEMP_DIR"
        return
    fi
    
    echo ""
    read -p "Обновить до версии $NEW_VERSION? (y/n): " confirm
    
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo -e "${YELLOW}Обновление отменено${NC}"
        cd - > /dev/null
        rm -rf "$TEMP_DIR"
        return
    fi
    
    # Резервная копия текущей версии
    echo -e "${YELLOW}Создание резервной копии...${NC}"
    cp "$SCRIPT_PATH" "$SCRIPT_PATH.backup"
    
    # Установка новой версии
    echo -e "${YELLOW}Установка новой версии...${NC}"
    cp system-updater.sh "$SCRIPT_PATH"
    chmod +x "$SCRIPT_PATH"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Приложение успешно обновлено!${NC}"
        echo -e "${CYAN}Новая версия: $NEW_VERSION${NC}"
        echo ""
        echo -e "${YELLOW}Резервная копия сохранена: $SCRIPT_PATH.backup${NC}"
        log_action "Приложение обновлено с $VERSION до $NEW_VERSION"
        
        # Очистка
        cd - > /dev/null
        rm -rf "$TEMP_DIR"
        
        echo ""
        read -p "Перезапустить приложение? (y/n): " restart
        if [ "$restart" = "y" ] || [ "$restart" = "Y" ]; then
            exec "$SCRIPT_PATH"
        fi
    else
        echo -e "${RED}✗ Ошибка установки${NC}"
        echo -e "${YELLOW}Восстановление из резервной копии...${NC}"
        cp "$SCRIPT_PATH.backup" "$SCRIPT_PATH"
        cd - > /dev/null
        rm -rf "$TEMP_DIR"
    fi
}

# Показать версию
show_version() {
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║   Ubuntu System Updater v$VERSION      ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo ""
}

# Главное меню
show_menu() {
    clear
    show_version
    echo -e "${CYAN}=== ОСНОВНОЕ ===${NC}"
    echo "1)  Сканировать и показать обновления"
    echo "2)  Обновить все компоненты"
    echo "3)  Обновить конкретный пакет"
    echo "4)  Полное обновление (dist-upgrade)"
    echo "5)  Обновления безопасности"
    echo ""
    echo -e "${CYAN}=== УПРАВЛЕНИЕ ПАКЕТАМИ ===${NC}"
    echo "6)  Установить пакет"
    echo "7)  Удалить пакет"
    echo "8)  Переустановить пакет"
    echo "9)  Поиск пакета"
    echo "10) Информация о пакете"
    echo ""
    echo -e "${CYAN}=== ОБСЛУЖИВАНИЕ ===${NC}"
    echo "11) Автоочистка системы"
    echo "12) Исправить зависимости"
    echo "13) Проверить целостность"
    echo "14) Удалить старые ядра"
    echo "15) Показать размер кэша"
    echo ""
    echo -e "${CYAN}=== ИНФОРМАЦИЯ ===${NC}"
    echo "16) Информация о системе"
    echo "17) Использование диска"
    echo "18) История обновлений"
    echo "19) Статистика обновлений"
    echo "20) Проверить перезагрузку"
    echo ""
    echo -e "${CYAN}=== ДОПОЛНИТЕЛЬНО ===${NC}"
    echo "21) Показать установленные пакеты"
    echo "22) Показать репозитории"
    echo "23) Показать зависимости"
    echo "24) Показать файлы пакета"
    echo "25) Найти пакет по файлу"
    echo ""
    echo -e "${CYAN}=== РЕЗЕРВНОЕ КОПИРОВАНИЕ ===${NC}"
    echo "26) Создать резервную копию"
    echo "27) Восстановить из копии"
    echo ""
    echo -e "${CYAN}=== РАСШИРЕННОЕ ===${NC}"
    echo "28) Удержать пакет"
    echo "29) Снять удержание"
    echo "30) Показать удерживаемые"
    echo "31) Симуляция обновления"
    echo "32) Загрузить пакет"
    echo "33) Показать changelog"
    echo "34) Тест скорости репозиториев"
    echo ""
    echo -e "${CYAN}=== ЛОГИ ===${NC}"
    echo "35) Экспорт логов"
    echo "36) Очистить логи"
    echo ""
    echo -e "${CYAN}=== АВТООБНОВЛЕНИЕ ===${NC}"
    echo "37) Настроить автообновление"
    echo "38) Отключить автообновление"
    echo "39) Статус автообновления"
    echo ""
    echo -e "${CYAN}=== СИСТЕМА ===${NC}"
    echo "40) Обновить приложение"
    echo ""
    echo "0)  Выход"
    echo ""
}

# Основной цикл
main() {
    check_root
    init_dirs
    
    while true; do
        show_menu
        read -p "Выберите действие (0-40): " choice
        
        case $choice in
            1) scan_updates; result=$?; [ $result -eq 0 ] && show_updates; read -p "Enter..." ;;
            2) scan_updates; result=$?; [ $result -eq 0 ] && update_all; read -p "Enter..." ;;
            3) scan_updates; result=$?; [ $result -eq 0 ] && { show_updates; update_specific; }; read -p "Enter..." ;;
            4) dist_upgrade; read -p "Enter..." ;;
            5) security_updates; read -p "Enter..." ;;
            6) install_package; read -p "Enter..." ;;
            7) remove_package; read -p "Enter..." ;;
            8) reinstall_package; read -p "Enter..." ;;
            9) search_package; read -p "Enter..." ;;
            10) show_package_info; read -p "Enter..." ;;
            11) auto_clean; read -p "Enter..." ;;
            12) fix_broken; read -p "Enter..." ;;
            13) check_integrity; read -p "Enter..." ;;
            14) remove_old_kernels; read -p "Enter..." ;;
            15) show_cache_size; read -p "Enter..." ;;
            16) show_system_info; read -p "Enter..." ;;
            17) show_disk_usage; read -p "Enter..." ;;
            18) show_history; read -p "Enter..." ;;
            19) show_update_stats; read -p "Enter..." ;;
            20) check_reboot_required; read -p "Enter..." ;;
            21) list_installed; read -p "Enter..." ;;
            22) show_repositories; read -p "Enter..." ;;
            23) show_dependencies; read -p "Enter..." ;;
            24) show_package_files; read -p "Enter..." ;;
            25) find_package_by_file; read -p "Enter..." ;;
            26) backup_packages; read -p "Enter..." ;;
            27) restore_packages; read -p "Enter..." ;;
            28) hold_package; read -p "Enter..." ;;
            29) unhold_package; read -p "Enter..." ;;
            30) show_held_packages; read -p "Enter..." ;;
            31) simulate_update; read -p "Enter..." ;;
            32) download_package; read -p "Enter..." ;;
            33) show_changelog; read -p "Enter..." ;;
            34) test_repo_speed; read -p "Enter..." ;;
            35) export_logs; read -p "Enter..." ;;
            36) clear_logs; read -p "Enter..." ;;
            37) setup_auto_update; read -p "Enter..." ;;
            38) disable_auto_update; read -p "Enter..." ;;
            39) show_auto_update_status; read -p "Enter..." ;;
            40) update_application; read -p "Enter..." ;;
            0) echo -e "${GREEN}Выход${NC}"; log_action "Программа завершена"; exit 0 ;;
            *) echo -e "${RED}Неверный выбор${NC}"; sleep 2 ;;
        esac
    done
}

# Запуск
clear
main
