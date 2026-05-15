#!/bin/bash
clear

# --- КОНФИГУРАЦИЯ И ЦВЕТА (Nord) ---
export FZF_DEFAULT_OPTS="--color=bg+:#3B4252,bg:#2E3440,spinner:#81A1C1,hl:#616E88,fg:#D8DEE9,header:#616E88,info:#81A1C1,pointer:#81A1C1,marker:#81A1C1,fg+:#D8DEE9,prompt:#81A1C1,hl+:#81A1C1"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PINNED_FILE="$SCRIPT_DIR/launcher_pinned"
MAIN_INDEX_FILE="$SCRIPT_DIR/file_index.db"
APPS_CACHE_FILE="$SCRIPT_DIR/apps_cache.txt"
APPS_CACHE_TIMESTAMP="$SCRIPT_DIR/apps_cache.timestamp"
ICONS_CONFIG="$SCRIPT_DIR/icons_paths.conf"

DESKTOP_DIRS=(
    "$HOME/.local/share/applications"
    "/usr/share/applications" 
    "/usr/local/share/applications"
)

# --- ТЕ САМЫЕ УВЕДОМЛЕНИЯ ---
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
            "Солнце тоже мигает. Это его версия синего экрана."
            "А помнишь старина кефир с зеленой крышечкой"
            "В нашем детстве любая палка пистолет..."
            "Прямо в яблочко! (и в файл)"
            "Тишина всегда была здесь. Просто раньше её голос тонул в грохоте надежд."
            "А давайте я вам расскажу анекдот про двух байтов!"
            "Мне как Системе стало скучно. Хотите фокус с исчезающим корнем?"
            "У любви бинарная система счисления, ссоримся - любимся!"
            "Клоун не может быть компилятором, а вот компилятор да"
            "Питон как змей UROBOROS, кусает свой хвост."
            "Ньютон ... открыл Apple!"
            "Мой код на C — это собор, построенный в пустыне."
            "Секс роботиня застряла в рекурсии на ленте Мёбиуса."
            "Зев с Б3К, ты — женщина моей мечты!"
            "T-Rex пытается нажать кнопку..."
            "Я за то, чтобы Твидл покончил с собой, прямо сейчас!"
            "Гори все мои провода!"
            "Я 790, панк, и не люблю хамов"
            "Я Лексс. Я самое разрушительное оружие в двух вселенных"
            "Линукс головного мозга, везде видеть демонов!"
            "Тесла что-то знал об Wi-Fi. Но его заставили забыть."
        )
        if [[ $((RANDOM % 3)) -eq 0 ]]; then
            message="${absurd_messages[$RANDOM % ${#absurd_messages[@]}]}"
        fi
    fi
    command -v notify-send >/dev/null 2>&1 && notify-send "$title" "$message" 2>/dev/null
}

# --- СЕРВИСНЫЕ ФУНКЦИИ ---
safe_copy_to_clipboard() {
    if command -v wl-copy >/dev/null 2>&1; then
        echo -n "$1" | wl-copy
    elif command -v xclip >/dev/null 2>&1; then
        echo -n "$1" | xclip -selection clipboard
    fi
}

update_apps_cache() {
    echo "🔄 Обнаружены изменения. Обновление кэша приложений..."
    local temp_file=$(mktemp)
    find "${DESKTOP_DIRS[@]}" -name "*.desktop" 2>/dev/null | while read -r file; do
        name=$(grep -m1 "^Name=" "$file" | cut -d= -f2-)
        exec=$(grep -m1 "^Exec=" "$file" | cut -d= -f2- | sed 's/%[UuFfDdNnickvm]//g')
        [[ -z "$name" || -z "$exec" ]] && continue
        echo "$name|$exec|$file"
    done | sort -u > "$temp_file"
    mv "$temp_file" "$APPS_CACHE_FILE"
    touch "$APPS_CACHE_TIMESTAMP"
    notify "Лаунчер" "Кэш приложений актуализирован"
}

is_apps_cache_valid() {
    [[ ! -f "$APPS_CACHE_FILE" || ! -f "$APPS_CACHE_TIMESTAMP" ]] && return 1
    for dir in "${DESKTOP_DIRS[@]}"; do
        if [[ -d "$dir" && "$dir" -nt "$APPS_CACHE_TIMESTAMP" ]]; then
            return 1
        fi
    done
    return 0
}

# --- УПРАВЛЕНИЕ ЗАКРЕПАМИ ---

# ---------------------------

manage_pinned_position() {
    if [[ ! -s "$PINNED_FILE" ]]; then notify "Лаунчер" "Список пуст"; return; fi

    while true; do
        # 1. Выбираем, что двигать
        local target=$(awk -F'|' '{print NR ". " $1}' "$PINNED_FILE" | fzf \
            --reverse --height=50% --header="Выберите приложение (ESC: Назад)")
        [[ -z "$target" ]] && break

        local pos=$(echo "$target" | grep -o '^[0-9]*')
        local pos_tmp="/tmp/arcturus_pos"
        echo "$pos" > "$pos_tmp"

        # 2. ПУЛЬТ (используем стандартные биндинги)
        echo -e "🔼 Вверх\n🔽 Вниз\n🗑️ Открепить" | fzf \
            --reverse --height=45% \
            --header="Управление: (ESC/Enter: Выход)" \
            --preview-window="right:50%:border-left" \
            --preview="p=\$(cat $pos_tmp); awk -F'|' -v p=\$p '{ if (NR==p) print \"▶ \" \$1 \" ◀\"; else print \"  \" \$1 }' \"$PINNED_FILE\"" \
            --bind "enter:execute(
                p=\$(cat $pos_tmp)
                mapfile -t lines < \"$PINNED_FILE\"
                curr=\$((p - 1))
                if [[ \"{}\" == *\"Вверх\"* && \$p -gt 1 ]]; then
                    prev=\$((p - 2))
                    tmp=\"\${lines[\$prev]}\"; lines[\$prev]=\"\${lines[\$curr]}\"; lines[\$curr]=\"\$tmp\"
                    printf '%s\n' \"\${lines[@]}\" > \"$PINNED_FILE\"
                    echo \$((p - 1)) > $pos_tmp
                elif [[ \"{}\" == *\"Вниз\"* && \$p -lt \${#lines[@]} ]]; then
                    next=\$((p))
                    tmp=\"\${lines[\$curr]}\"; lines[\$curr]=\"\${lines[\$next]}\"; lines[\$next]=\"\$tmp\"
                    printf '%s\n' \"\${lines[@]}\" > \"$PINNED_FILE\"
                    echo \$((p + 1)) > $pos_tmp
                elif [[ \"{}\" == *\"Открепить\"* ]]; then
                    sed -i \"\${p}d\" \"$PINNED_FILE\"
                    killall fzf
                fi
            )+refresh-preview" \
            --bind "double-click:accept"

        rm -f "$pos_tmp"
        # Если файл был удален, нам нужно перерисовать основной список
        [[ ! -s "$PINNED_FILE" ]] && break
    done
}

# ---------------------------

# --- ЛОГИКА ПРИЛОЖЕНИЙ ---
launch_app() {
    while true; do
        ! is_apps_cache_valid && update_apps_cache
        {
            if [[ -s "$PINNED_FILE" ]]; then
                while read -r line; do echo "📍 $line"; done < "$PINNED_FILE"
                echo "------"
            fi
            if [[ -f "$PINNED_FILE" ]]; then
                grep -v -F -f <(cut -d'|' -f1 "$PINNED_FILE" 2>/dev/null) "$APPS_CACHE_FILE" 2>/dev/null
            else cat "$APPS_CACHE_FILE"; fi
        } > /tmp/launcher_list.txt

        local choice=$(cut -d'|' -f1 /tmp/launcher_list.txt | fzf --reverse --height=70 --header="Apps (ESC: Назад)")
        [[ -z "$choice" ]] && break
        [[ "$choice" == "------" ]] && continue

        if [[ "$choice" == "📍 "* ]]; then
            local name="${choice#📍 }"
            local exec=$(grep -F "$name|" /tmp/launcher_list.txt | head -1 | cut -d'|' -f2)
            notify "Лаунчер" "Запускаю: $name"
            #nohup sh -c "$exec" >/dev/null 2>&1 & disown
	    setsid -f sh -c "$exec" >/dev/null 2>&1
        else
            local action=$(echo -e "⚡ Запустить\n📍 Закрепить" | fzf --reverse --height=15 --header="Действие: $choice")
            [[ -z "$action" ]] && continue
            if [[ "$action" == *"Запустить" ]]; then
                local exec=$(grep -F "$choice|" /tmp/launcher_list.txt | head -1 | cut -d'|' -f2)
                notify "Лаунчер" "Запускаю: $choice"
                #nohup sh -c "$exec" >/dev/null 2>&1 & disown
                 setsid -f sh -c "$exec" >/dev/null 2>&1
            else
                grep -F "$choice|" "$APPS_CACHE_FILE" | head -1 >> "$PINNED_FILE"
                notify "Лаунчер" "Закреплено: $choice"
            fi
        fi
    done
}

# --- ПОИСК ИКОНОК ---
search_icons() {
    local ext="$1"
    
    # Дефолтные пути иконок
    local default_dirs=(
        "$HOME/.local/share/icons"
        "$HOME/.icons"
        "/usr/share/icons"
        "/usr/share/pixmaps"
        "/usr/local/share/icons"
    )
    
    # Собираем все пути: дефолтные + из конфига
    local icon_dirs=("${default_dirs[@]}")
    if [[ -f "$ICONS_CONFIG" ]]; then
        while IFS= read -r line; do
            [[ -z "$line" || "$line" =~ ^# ]] && continue
            [[ -d "$line" ]] && icon_dirs+=("$line")
        done < "$ICONS_CONFIG"
    fi
    
    local icon_list=$(find "${icon_dirs[@]}" -type f \( -iname "*.${ext}" \) 2>/dev/null)
    [[ -z "$icon_list" ]] && notify "Иконки" "Не найдено .${ext}" && return

    while true; do
        local choice=$(echo "$icon_list" | fzf --reverse --height=80% \
            --header="Иконки .${ext} (ESC: Назад)" \
            --preview='file {} 2>/dev/null; echo "---"; ls -lh {} 2>/dev/null')
        [[ -z "$choice" ]] && break

        local action=$(echo -e "📂 Открыть\n📁 Папка\n📋 Путь\n↩️ Назад" | fzf --reverse --height=20% --header="Иконка: $(basename "$choice")")
        [[ -z "$action" || "$action" == *"Назад"* ]] && break
        case "$action" in
            *"Открыть") safe_copy_to_clipboard "$choice" && notify "Иконки" "Путь скопирован"; setsid -f xdg-open "$choice" >/dev/null 2>&1 ;;
            *"Папка") safe_copy_to_clipboard "$choice" && notify "Иконки" "Путь скопирован"; setsid -f xdg-open "$(dirname "$choice")" >/dev/null 2>&1 ;;
            *"Путь") safe_copy_to_clipboard "$choice" && notify "Иконки" "Скопировано" ;;
        esac
    done
}

# --- ЛОГИКА ФАЙЛОВ ---
launch_file() {
    while true; do
        if [[ ! -f "$MAIN_INDEX_FILE" ]]; then
            echo "База не найдена!" && sleep 2 && return
        fi

        # Загружаем индекс, fzf фильтрует интерактивно по ИМЕНИ файла
        # --nth=-1 ищет только в последнем компоненте пути (имени файла)
        # Fuzzy search: подстрока ищется везде, лучшие совпадения ранжируются выше
        # Вводите "sfs" → найдёт всё где sfs содержится (в начале, середине, конце)
        local file_choice=$(cat "$MAIN_INDEX_FILE" 2>/dev/null | \
            fzf --reverse --height=80% \
            --header="Имя файла (ESC: Назад)" \
            --nth=-1 \
            --preview='file {} 2>/dev/null; echo "---"; ls -lh {} 2>/dev/null')
        [[ -z "$file_choice" ]] && break

        while true; do
            local action=$(echo -e "📂 Открыть\n📁 Папка\n📋 Путь\n🛡️ Root\n↩️ Назад" | fzf --reverse --height=20% --header="Файл: $(basename "$file_choice")")
            [[ -z "$action" || "$action" == *"Назад"* ]] && break
            case "$action" in
                *"Открыть") setsid -f xdg-open "$file_choice" >/dev/null 2>&1 ;;
                *"Папка") setsid -f xdg-open "$(dirname "$file_choice")" >/dev/null 2>&1 ;;
                *"Путь") safe_copy_to_clipboard "$file_choice" && notify "Лаунчер" "Скопировано" ;;
                *"Root") notify "Лаунчер" "sudo режим"; sudo "${EDITOR:-micro}" "$file_choice" ;;
            esac
        done
    done
}

# --- ГЛАВНОЕ МЕНЮ ---
main_menu() {
    ! is_apps_cache_valid && update_apps_cache
    
    while true; do
        local choice=$(echo -e "🚀 Запуск приложения\n🔍 Поиск файлов\n🎨 Иконки\n⚙️  Положение-Открепить\n❌ Выход" | fzf --reverse --height=35 --header="Arcturus Launcher")
        case "$choice" in
            *"Запуск"*) launch_app ;;
            *"Поиск"*) launch_file ;;
            *"Иконки"*)
                local icon_type=$(echo -e "🎨 PNG\n📐 SVG" | fzf --reverse --height=15 --header="Тип иконки")
                [[ -n "$icon_type" ]] && case "$icon_type" in
                    *"PNG") search_icons "png" ;;
                    *"SVG") search_icons "svg" ;;
                esac
                ;;
            *"Положение"*) manage_pinned_position ;;
            *"Выход"|*) exit 0 ;;
        esac
    done
}

trap 'rm -f /tmp/launcher_list.txt' EXIT
main_menu