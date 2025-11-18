#!/bin/bash

# Цветная тема для fzf (Nord theme)
export FZF_DEFAULT_OPTS="--color=bg+:#3B4252,bg:#2E3440,spinner:#81A1C1,hl:#616E88,fg:#D8DEE9,header:#616E88,info:#81A1C1,pointer:#81A1C1,marker:#81A1C1,fg+:#D8DEE9,prompt:#81A1C1,hl+:#81A1C1"

# Получаем директорию, где находится скрипт
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Файлы конфигурации
PINNED_FILE="$SCRIPT_DIR/launcher_pinned"
MAIN_INDEX_FILE="$SCRIPT_DIR/file_index.db"
APPS_CACHE_FILE="$SCRIPT_DIR/apps_cache.txt"
APPS_CACHE_TIMESTAMP="$SCRIPT_DIR/apps_cache.timestamp"

DESKTOP_DIRS=(
    "$HOME/.local/share/applications"
    "/usr/share/applications" 
    "/usr/local/share/applications"
)

# Функция для уведомлений со случайными абсурдными сообщениями
notify() {
    local title="$1"
    local message="$2"
    
    if [[ "$title" == "Лаунчер" ]]; then
        local absurd_messages=(
            "Ваш тостер сочувствует вашим жизненным выборам... Немного."
            "Улицам нравится, когда вы теряетесь. Продолжайте."
            "У интернета есть исподняя, но её не поменять"
            "Разыгрываю драматическую сцену запуска"
            "Ищу инструкцию в Википедии..."
            "Товарищь майор погодите звонить, я натяну штаны!"
            "У рая есть сантехника, но она протекает с самого начала."
            "Осьминог тестирует всеми щупальцами"
            "Сердце вселенной бьётся с перебоями. Гарантия закончилась."
            "01001000 01101001 00100001 (Hi!)"
            "Launcher symphony in C# major"
            "Сердце вселенной бьётся с перебоями. Гарантия закончилась."
            "Солнце тоже мигает. Это его версия синего экрана."
            "А помнишь старина кефир с зеленой крышечкой"
            "В нашем детстве любая палка пистолет--а сегодня сетуем по телефону что возможностей так мало"
            "Прямо в яблочко! (и в файл)"
            "Тишина всегда была здесь. Просто раньше её голос тонул в грохоте надежд."
            "А давайте я вам расскажу анекдот про двух байтов!"
            "Мне как Системе стало скучно. Хотите, я покажу вам фокус с исчезающим корнем?"
            "У любви бинарная система счисления, ссоримся - любимся!"
            "Клоун не может быть компиляторм, а вот компилятор да"
            "Питон как змей UROBOROS , кусает свой хвост, но он не виноват что он интерпретируемый."
            "Ньютон ... открыл Aplle!"
            "Мой код на C — это собор, построенный в пустыне. Прекрасен, но богу здесь не молятся."
            "Секс роботиня застряла в рекурсии на ленте Мёбиуса искала, с чего начать обслуживание."
            "Зев с Б3К, ты — женщина моей мечты!"
            "T-Rex пытается нажать кнопку..."
            "Мир — пустой звук. Важна только Зев"
            "Я за то, чтобы Твидл покончил с собой, прямо сейчас! Мы заслужили это удовольствие!"
            "Гори все мои провода!"
            "Я 790, панк, и не люблю хамов"
            "Я Лексс. Я самое разрушительное оружие в двух вселенных"
            "Его Тень: Убей их! Кай: Я этого не сделаю. Его Тень: Тогда убей себя! Кай: Я уже мёртв"
            "Линукс головного мозга,везде видеть демонов!"
            "Во Вселенной Света я был темнотой, возможно, в Тёмной Зоне, я стану светом"
            "Тесла что то знал об Wi-Fi. Но его заставили забыть."
        )
        
        if [[ $((RANDOM % 3)) -eq 0 ]]; then
            local random_index=$((RANDOM % ${#absurd_messages[@]}))
            message="${absurd_messages[$random_index]}"
        fi
    fi
    
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "$title" "$message" 2>/dev/null
    else
        echo "$title: $message" >&2
    fi
}

# Функция для проверки выхода через Escape
check_escape() {
    local result="$1"
    if [[ -z "$result" ]]; then
        return 0
    else
        return 1
    fi
}

# Функция для проверки зависимости
check_dependency() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "❌ Отсутствует зависимость: $1"
        return 1
    fi
    return 0
}

# Функция для получения размеров терминала
get_terminal_height() {
    tput lines 2>/dev/null || echo 24
}

get_terminal_width() {
    tput cols 2>/dev/null || echo 80
}

# Функция проверки наличия файлового индекса
check_file_index() {
    if [[ ! -f "$MAIN_INDEX_FILE" ]] || [[ ! -s "$MAIN_INDEX_FILE" ]]; then
        local term_height=$(get_terminal_height)
        local fzf_height=$((term_height / 3))
        
        echo -e "База файлов не найдена\n\nСоздайте базу через:\n./file_indexer.sh --init\n\nИли настройте автоматическое обновление:\n./file_indexer.sh --setup-cron" | \
        fzf --reverse --height=$fzf_height --header="Arcturus Launcher (Escape - выход)"
        return 1
    fi
    return 0
}

# Функция проверки актуальности кэша приложений
is_apps_cache_valid() {
    [[ ! -f "$APPS_CACHE_FILE" ]] && return 1
    [[ ! -f "$APPS_CACHE_TIMESTAMP" ]] && return 1
    
    local cache_time=$(cat "$APPS_CACHE_TIMESTAMP" 2>/dev/null || echo 0)
    local current_time=$(date +%s)
    local cache_age=$((current_time - cache_time))
    
    # Обновляем раз в сутки
    [[ $cache_age -gt 86400 ]] && return 1
    
    for dir in "${DESKTOP_DIRS[@]}"; do
        if [[ -d "$dir" ]]; then
            if find "$dir" -name "*.desktop" -newer "$APPS_CACHE_TIMESTAMP" 2>/dev/null | grep -q .; then
                return 1
            fi
        fi
    done
    
    return 0
}

# Функция обновления кэша приложений
update_apps_cache() {
    echo "Обновление кэша приложений..."
    
    local temp_file=$(mktemp)
    local count=0
    
    find "${DESKTOP_DIRS[@]}" -name "*.desktop" 2>/dev/null | \
    while read -r file; do
        name=$(grep -m1 "^Name=" "$file" | cut -d= -f2)
        exec=$(grep -m1 "^Exec=" "$file" | cut -d= -f2 | sed 's/%[UuFfDdNnickvm]//g')
        [[ -z "$name" || -z "$exec" ]] && continue
        echo "$name|$exec|$file"
        ((count++))
    done | sort -u > "$temp_file"
    
    if [[ -s "$temp_file" ]]; then
        mv "$temp_file" "$APPS_CACHE_FILE"
        date +%s > "$APPS_CACHE_TIMESTAMP"
        local final_count=$(wc -l < "$APPS_CACHE_FILE")
        echo "✓ Кэш обновлен: $final_count приложений"
        notify "Лаунчер" "Кэш приложений обновлён"
    else
        echo "✗ Не удалось обновить кэш приложений"
        rm -f "$temp_file"
        return 1
    fi
}

# Функция запуска приложения
launch_application() {
    local exec_command="$1"
    local app_name="$2"
    
    notify "Лаунчер" "Запускаю: $app_name"
    nohup sh -c "$exec_command" >/dev/null 2>&1 &
    disown
}

# Функция для управления позицией закрепленных приложений
manage_pinned_position() {
    if [[ ! -f "$PINNED_FILE" ]] || [[ ! -s "$PINNED_FILE" ]]; then
        local term_height=$(get_terminal_height)
        local fzf_height=$((term_height / 3))
        echo "Нет закрепленных приложений" | fzf --reverse --height=$fzf_height --header="Escape - назад"
        return 1
    fi
    
    while true; do
        local term_height=$(get_terminal_height)
        local fzf_height=$((term_height / 2))
        local preview_width=$(( $(get_terminal_width) / 3 ))
        
        # Получаем список закрепленных приложений
        local pinned_list=""
        local index=1
        while read -r line; do
            if [[ -n "$line" ]]; then
                local app_name=$(echo "$line" | cut -d'|' -f1)
                pinned_list+="$index. $app_name"$'\n'
                ((index++))
            fi
        done < "$PINNED_FILE"
        
        # Выбираем приложение для управления позицией
        local choice=$(echo -e "$pinned_list" | fzf \
            --reverse \
            --height=$fzf_height \
            --header="Выберите приложение для управления позицией (Escape - назад)" \
            --preview="cat \"$PINNED_FILE\" | awk -v pos=1 'BEGIN{print \"==============\"; print \"  ЗАКРЕПЛЕННЫЕ\n....ПРИЛОЖЕНИЯ      \"; print \"==============\"; print \"\"} NF{split(\$0, a, \"|\"); if(NR==pos) printf \">> %2d. %s <<\n\", NR, a[1]; else printf \"   %2d. %s\n\", NR, a[1]}'" \
            --preview-window=right:${preview_width}%:wrap 2>/dev/null)
        
        if check_escape "$choice"; then
            return 0
        fi
        
        # Извлекаем номер позиции
        local pos=$(echo "$choice" | grep -o '^[0-9]*' | head -1)
        
        if [[ -z "$pos" ]]; then
            continue
        fi
        
        # Получаем строку с приложением
        local app_line=$(sed -n "${pos}p" "$PINNED_FILE" 2>/dev/null)
        
        if [[ -z "$app_line" ]]; then
            continue
        fi
        
        local app_name=$(echo "$app_line" | cut -d'|' -f1)
        local total_lines=$(wc -l < "$PINNED_FILE" 2>/dev/null || echo 0)
        
        # Показываем меню управления позицией
        while true; do
            local action=$(echo -e "⬆ Вверх\n⬇ Вниз\n✕ Открепить\n← Назад" | fzf \
                --reverse \
                --height=$fzf_height \
                --header="Управление: $app_name [позиция: $pos/$total_lines] (Escape - в меню выбора)" \
                --preview="cat \"$PINNED_FILE\" | awk -v pos=$pos 'BEGIN{print \"==============\"; print \"  ЗАКРЕПЛЕННЫЕ\n....ПРИЛОЖЕНИЯ      \"; print \"==============\"; print \"\"} NF{split(\$0, a, \"|\"); if(NR==pos) printf \">> %2d. %s <<\n\", NR, a[1]; else printf \"   %2d. %s\n\", NR, a[1]}'" \
                --preview-window=right:${preview_width}%:wrap 2>/dev/null)
            
            if check_escape "$action"; then
                break
            fi
            
            case "$action" in
                "⬆ Вверх")
                    if [[ $pos -gt 1 ]]; then
                        # Читаем файл в массив
                        mapfile -t lines < "$PINNED_FILE"
                        
                        # Меняем местами строки (индексы от 0)
                        local prev_pos=$((pos - 2))
                        local curr_pos=$((pos - 1))
                        
                        local temp="${lines[$prev_pos]}"
                        lines[$prev_pos]="${lines[$curr_pos]}"
                        lines[$curr_pos]="$temp"
                        
                        # Записываем обратно
                        printf '%s\n' "${lines[@]}" > "$PINNED_FILE"
                        
                        # Обновляем позицию
                        ((pos--))
                        
                        notify "Лаунчер" "Приложение переместилось вверх"
                    else
                        notify "Лаунчер" "Приложение уже в начале списка"
                    fi
                    ;;
                "⬇ Вниз")
                    if [[ $pos -lt $total_lines ]]; then
                        # Читаем файл в массив
                        mapfile -t lines < "$PINNED_FILE"
                        
                        # Меняем местами строки (индексы от 0)
                        local curr_pos=$((pos - 1))
                        local next_pos=$((pos))
                        
                        local temp="${lines[$curr_pos]}"
                        lines[$curr_pos]="${lines[$next_pos]}"
                        lines[$next_pos]="$temp"
                        
                        # Записываем обратно
                        printf '%s\n' "${lines[@]}" > "$PINNED_FILE"
                        
                        # Обновляем позицию
                        ((pos++))
                        
                        notify "Лаунчер" "Приложение переместилось вниз"
                    else
                        notify "Лаунчер" "Приложение уже в конце списка"
                    fi
                    ;;
                "✕ Открепить")
                    # Удаляем приложение из конфига
                    local temp_file=$(mktemp)
                    sed "${pos}d" "$PINNED_FILE" > "$temp_file"
                    mv "$temp_file" "$PINNED_FILE"
                    notify "Лаунчер" "Откреплено: $app_name"
                    
                    # Выходим из внутреннего цикла и возвращаемся к выбору приложения
                    break
                    ;;
                "← Назад")
                    # Просто выходим из внутреннего цикла
                    break
                    ;;
            esac
        done
    done
}

# Основной лаунчер приложений
launch_app() {
    while true; do
        if ! is_apps_cache_valid; then
            update_apps_cache
        fi
        
        cp "$APPS_CACHE_FILE" /tmp/all_apps.txt

        {
            if [[ -f "$PINNED_FILE" ]] && [[ -s "$PINNED_FILE" ]]; then
                while read -r line; do
                    echo ":: $line"
                done < "$PINNED_FILE"
                echo "------"
            fi
            if [[ -f "$PINNED_FILE" ]]; then
                grep -v -f <(cut -d'|' -f1 "$PINNED_FILE" 2>/dev/null) /tmp/all_apps.txt 2>/dev/null
            else
                cat /tmp/all_apps.txt
            fi
        } > /tmp/launcher_list.txt

        local term_height=$(get_terminal_height)
        local fzf_height=70

        choice=$(cut -d'|' -f1 /tmp/launcher_list.txt | fzf --reverse --height=$fzf_height --header="Arcturus Launcher (Escape - назад в главное меню)")
        
        if check_escape "$choice"; then
            rm -f /tmp/all_apps.txt /tmp/launcher_list.txt
            return 0
        fi

        if [[ -n "$choice" ]]; then
            if [[ "$choice" == ":: "* ]]; then
                # Закрепленное приложение - сразу запускаем
                app_name="${choice#:: }"
                exec=$(grep -F "$app_name|" /tmp/launcher_list.txt | cut -d'|' -f2)
                launch_application "$exec" "$app_name"
                continue
            elif [[ "$choice" == "------" ]]; then
                continue
            else
                # Обычное приложение - показываем меню действий
                local fzf_height_submenu=15
                
                action=$(echo -e "Запустить\nЗакрепить" | fzf --reverse --height=$fzf_height_submenu --header="Действие для: $choice (Escape - назад)")
                
                if check_escape "$action"; then
                    continue
                fi
                
                case "$action" in
                    "Запустить")
                        exec=$(grep -F "$choice|" /tmp/launcher_list.txt | cut -d'|' -f2)
                        launch_application "$exec" "$choice"
                        continue
                        ;;
                    "Закрепить")
                        grep -F "$choice|" /tmp/launcher_list.txt >> "$PINNED_FILE"
                        notify "Лаунчер" "Закреплено: $choice"
                        continue
                        ;;
                esac
            fi
        fi
        
        rm -f /tmp/all_apps.txt /tmp/launcher_list.txt
    done
}

# Функция поиска файлов
launch_file() {
    while true; do
        local query="$1"
        
        if ! check_file_index; then
            return 1
        fi
        
        local term_height=$(get_terminal_height)
        local fzf_height=70
        local preview_width=$(( $(get_terminal_width) / 3 ))

        local file_choice=$(cat "$MAIN_INDEX_FILE" | fzf --reverse --height=$fzf_height% \
            --prompt="Поиск файлов: " \
            --query="$query" \
            --preview='file {} 2>/dev/null; echo "---"; ls -lh {} 2>/dev/null' \
            --preview-window=right:${preview_width}%:wrap \
            --header="Введите запрос для поиска (Escape - назад)")
        
        if check_escape "$file_choice"; then
            return 0
        fi
        
        if [[ -n "$file_choice" ]] && [[ -e "$file_choice" ]]; then
            while true; do
                local term_height=$(get_terminal_height)
                local fzf_height=$((term_height / 3))
                
                local action=$(echo -e "Запустить (xdg-open)\nОткрыть в файловом менеджере\nКопировать полный путь\nПоказать информацию\nРедактировать как root\n← Назад к поиску" | \
                    fzf --reverse --height=$fzf_height --header="Файл: $(basename "$file_choice") (Escape - назад)")
                
                if check_escape "$action"; then
                    break
                fi
                
                case "$action" in
                    "Запустить (xdg-open)")
                        notify "Лаунчер" "Открываю: $(basename "$file_choice")"
                        nohup xdg-open "$file_choice" >/dev/null 2>&1 &
                        disown
                        ;;
                    "Открыть в файловом менеджере")
                        local dir=$(dirname "$file_choice")
                        notify "Лаунчер" "Открываю папку: $dir"
                        nohup xdg-open "$dir" >/dev/null 2>&1 &
                        disown
                        ;;
                    "Копировать полный путь")
                        if command -v xclip >/dev/null 2>&1; then
                            echo "$file_choice" | xclip -selection clipboard
                            notify "Лаунчер" "Путь скопирован"
                        elif command -v wl-copy >/dev/null 2>&1; then
                            echo "$file_choice" | wl-copy
                            notify "Лаунчер" "Путь скопирован"
                        else
                            notify "Лаунчер" "Не установлен xclip или wl-copy"
                        fi
                        ;;
                    "Показать информацию")
                        local info=$(file "$file_choice" 2>/dev/null; echo "---"; ls -lh "$file_choice" 2>/dev/null)
                        echo "$info" | fzf --reverse --height=$fzf_height --header="Информация о файле (Escape - назад к действиям)"
                        ;;
                    "Редактировать как root")
                        if command -v sudo >/dev/null 2>&1; then
                            local editor="${EDITOR:-nano}"
                            notify "Лаунчер" "Открываю редактор с правами root"
                            sudo "$editor" "$file_choice"
                        else
                            notify "Лаунчер" "sudo не доступен"
                        fi
                        ;;
                    "← Назад к поиску")
                        break
                        ;;
                esac
            done
        fi
    done
}

# Главное меню
main_menu() {
    if ! check_dependency "fzf"; then
        echo "❌ Установите fzf: sudo apt install fzf"
        exit 1
    fi
    
    while true; do
        local term_height=$(get_terminal_height)
        local fzf_height=35
        
        local main_choice=$(echo -e "Запуск приложения\nПоиск файлов\nПоложение-Открепить\nВыход" | \
            fzf --reverse --height=$fzf_height --header="Arcturus Launcher - Главное меню (Escape - выход)")
        
        if [[ -z "$main_choice" ]]; then
            notify "Arcturus" "До свидания!"
            exit 0
        fi
        
        case "$main_choice" in
            "Запуск приложения")
                launch_app
                ;;
            "Поиск файлов")
                launch_file "" 
                ;;
            "Положение-Открепить")
                manage_pinned_position 
                ;;
            "Выход")
                notify "Arcturus" "До свидания!"
                exit 0
                ;;
        esac
    done
}

# Запуск
if [[ $# -gt 0 ]]; then
    launch_file "$1"
else
    main_menu
fi