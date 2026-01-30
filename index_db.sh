#!/bin/bash

# Определение путей
SCRIPT_PATH="$(readlink -f "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
MAIN_INDEX_FILE="$SCRIPT_DIR/file_index.db"
INDEX_TIMESTAMP_FILE="${MAIN_INDEX_FILE}.timestamp"

# Исключения (игнорируем системный мусор и тяжелые кэши браузеров)
EXCLUDE_REGEXP='^(/proc|/sys|/dev|/run|/tmp|/var/tmp|/var/cache|/var/log|/snap/|/var/lib/docker|.*/\.cache|.*/\.mozilla|.*/\.config/(google-chrome|chromium|BraveSoftware|opera|vivaldi|thorium)|.*/snap/(firefox|chromium)|.*/\.local/share/Trash)'

# Функция уведомлений (адаптированная под cron)
notify() {
    # Пытаемся подцепить сессию текущего пользователя для вывода уведомления на рабочий стол
    export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
    command -v notify-send >/dev/null 2>&1 && notify-send "Arcturus Indexer" "$1" 2>/dev/null
}

update_index() {
    echo "📊 Обновление системной базы plocate..."
    sudo updatedb 2>/dev/null

    echo "🔄 Создание среза индекса файлов..."
    plocate -r '^/' | grep -a -v -E "$EXCLUDE_REGEXP" > "${MAIN_INDEX_FILE}.tmp"
    
    if [[ -s "${MAIN_INDEX_FILE}.tmp" ]]; then
        # Считаем количество строк (файлов)
        local count=$(wc -l < "${MAIN_INDEX_FILE}.tmp")
        
        mv "${MAIN_INDEX_FILE}.tmp" "$MAIN_INDEX_FILE"
        date +%s > "$INDEX_TIMESTAMP_FILE"
        
        echo "✅ Индекс обновлен успешно: $count файлов"
        # Добавляем число и в уведомление
        notify "База обновлена: $count файлов"
    else
        echo "❌ Ошибка: индекс пуст"
        rm -f "${MAIN_INDEX_FILE}.tmp"
    fi
}

setup_cron() {
    # Формируем задачу cron
    local cron_job="*/30 * * * * PATH=\$PATH:/usr/bin:/usr/local/bin \"$SCRIPT_PATH\""
    
    # Проверяем, есть ли уже такая задача
    if crontab -l 2>/dev/null | grep -q "$SCRIPT_PATH"; then
        echo "✅ Автозапуск в cron уже активен (каждые 30 мин)"
    else
        (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
        echo "🆗 Автозапуск в cron успешно настроен"
    fi
}

main() {
    # Проверка наличия plocate
    if ! command -v plocate >/dev/null 2>&1; then
        echo "Ошибка: plocate не найден в системе"
        exit 1
    fi
    
    update_index
    setup_cron
}

main