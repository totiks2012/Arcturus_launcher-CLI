#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_INDEX_FILE="$SCRIPT_DIR/file_index.db"
INDEX_TIMESTAMP_FILE="${MAIN_INDEX_FILE}.timestamp"

# Функция для уведомлений
notify() {
    local title="$1"
    local message="$2"
    
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "$title" "$message" 2>/dev/null
    fi
}

# Функция проверки зависимостей
check_dependencies() {
    if ! command -v plocate >/dev/null 2>&1; then
        echo "❌ Установите plocate: sudo apt install plocate"
        return 1
    fi
    return 0
}

# Функция создания полного индекса
create_full_index() {
    echo "🔄 Создание полного индекса файлов..."
    
    # ОБНОВЛЯЕМ БАЗУ PLOCATE ПЕРЕД ИСПОЛЬЗОВАНИЕМ
    echo "📊 Обновляю базу plocate..."
    sudo updatedb 2>/dev/null
    
    local temp_file=$(mktemp)
    local count=0
    
    # Используем plocate и фильтруем результат
    plocate -r '^/' 2>/dev/null | \
    grep -v -E '^(/proc|/sys|/dev|/run|/tmp|/var/tmp|/var/cache|/var/log|/snap/|/var/lib/docker)' | \
    grep -v -E '(\.cache|\.mozilla|\.config/(google-chrome|chromium|BraveSoftware|opera|vivaldi|thorium)|snap/(firefox|chromium)|\.local/share/Trash)' | \
    while IFS= read -r line; do
        if [[ -f "$line" ]] && [[ ! -L "$line" ]]; then
            echo "$line"
            ((count++))
            if [[ $((count % 10000)) -eq 0 ]]; then
                echo "Обработано: $count файлов"
            fi
        fi
    done > "$temp_file"
    
    if [[ -s "$temp_file" ]]; then
        sort -u "$temp_file" > "$MAIN_INDEX_FILE"
        date +%s > "$INDEX_TIMESTAMP_FILE"
        local final_count=$(wc -l < "$MAIN_INDEX_FILE")
        echo "✅ Полный индекс создан: $final_count файлов"
        notify "Индексатор" "Полный индекс создан: $final_count файлов"
    else
        echo "❌ Не удалось создать индекс"
        return 1
    fi
    
    rm -f "$temp_file"
}

# Функция инкрементального обновления
update_index() {
    if [[ ! -f "$MAIN_INDEX_FILE" ]] || [[ ! -f "$INDEX_TIMESTAMP_FILE" ]]; then
        echo "❌ Полный индекс не найден. Создаю..."
        create_full_index
        return $?
    fi
    
    echo "🔄 Инкрементальное обновление индекса..."
    
    # ОБНОВЛЯЕМ БАЗУ PLOCATE ПЕРЕД ИСПОЛЬЗОВАНИЕМ
    echo "📊 Обновляю базу plocate..."
    sudo updatedb 2>/dev/null
    
    local last_update=$(cat "$INDEX_TIMESTAMP_FILE")
    local temp_new_files=$(mktemp)
    local new_files_count=0
    
    # Ищем новые файлы через plocate
    plocate --newer "$last_update" 2>/dev/null | \
    grep -v -E '^(/proc|/sys|/dev|/run|/tmp|/var/tmp|/var/cache|/var/log|/snap/|/var/lib/docker)' | \
    grep -v -E '(\.cache|\.mozilla|\.config/(google-chrome|chromium|BraveSoftware|opera|vivaldi|thorium)|snap/(firefox|chromium)|\.local/share/Trash)' | \
    while IFS= read -r line; do
        [[ -f "$line" ]] && [[ ! -L "$line" ]] && echo "$line"
    done > "$temp_new_files"
    
    if [[ -s "$temp_new_files" ]]; then
        # Фильтруем уже существующие файлы
        awk 'NR == FNR {a[$0]++; next} !a[$0]' "$MAIN_INDEX_FILE" "$temp_new_files" > "${temp_new_files}.filtered"
        new_files_count=$(wc -l < "${temp_new_files}.filtered" 2>/dev/null || echo 0)
        
        if [[ $new_files_count -gt 0 ]]; then
            cat "${temp_new_files}.filtered" >> "$MAIN_INDEX_FILE"
            sort -u "$MAIN_INDEX_FILE" -o "$MAIN_INDEX_FILE"
            date +%s > "$INDEX_TIMESTAMP_FILE"
            echo "✅ Добавлено новых файлов: $new_files_count"
            notify "Индексатор" "Добавлено: $new_files_count файлов"
        else
            echo "✅ Новых файлов не найдено"
        fi
        
        rm -f "${temp_new_files}.filtered"
    else
        echo "✅ Новых файлов не найдено"
    fi
    
    date +%s > "$INDEX_TIMESTAMP_FILE"
    rm -f "$temp_new_files"
}

# Функция настройки cron
setup_cron() {
    local script_path="$0"
    
    # Делаем скрипт исполняемым
    chmod +x "$script_path"
    
    # Добавляем в cron
    if crontab -l 2>/dev/null | grep -q "$script_path"; then
        echo "✅ Задача cron уже настроена"
    else
        (crontab -l 2>/dev/null; echo "*/30 * * * * $script_path") | crontab -
        echo "✅ Задача cron добавлена: обновление каждые 30 минут"
    fi
}

# Основная логика - ВСЕ АВТОМАТИЧЕСКИ
main() {
    # Проверяем зависимости
    if ! check_dependencies; then
        exit 1
    fi
    
    # Если базы нет - создаем
    if [[ ! -f "$MAIN_INDEX_FILE" ]]; then
        echo "📁 База не найдена, создаем..."
        create_full_index
        
        # После создания базы настраиваем автообновление
        if [[ -f "$MAIN_INDEX_FILE" ]]; then
            echo "⚙️ Настраиваю автоматическое обновление..."
            setup_cron
        fi
    else
        # Если база есть - инкрементальное обновление
        update_index
    fi
    
    echo "✅ Готово!"
}

# Запускаем автоматически
main