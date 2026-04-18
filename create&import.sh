#!/bin/bash
# Создание и автоматическое восстановление базы 1С через ibcmd create --restore

# 1. Поиск путей
VER_DIR=$(ls /opt/1cv8/x86_64/ | grep -E "^8\." | head -n 1)
IBCMD_PATH="/opt/1cv8/x86_64/$VER_DIR/ibcmd"

if [ ! -f "$IBCMD_PATH" ]; then
    echo "❌ Ошибка: Утилита ibcmd не найдена."
    exit 1
fi

clear
echo "====================================================="
echo "   Создание + Загрузка базы 1С (Метод ibcmd create)"
echo "====================================================="

# 2. Сбор данных
read -p "Имя новой базы (лат.): " DB_NAME
read -sp "Пароль СУБД (postgres): " PG_PASS
echo -e "\n"

# 3. Поиск .dt файлов (Текущая и Домашняя папки)
echo "Поиск файлов .dt для загрузки..."
mapfile -t FILES < <(ls *.dt ~/ *.dt 2>/dev/null | sort -u)
COUNT=${#FILES[@]}

if [ $COUNT -gt 0 ]; then
    for i in "${!FILES[@]}"; do
        echo "$((i+1))) $(realpath "${FILES[$i]}")"
    done
    echo "$((COUNT+1))) Загрузить из интернета (mlgo.ru)"
    echo "$((COUNT+2))) Создать ПУСТУЮ базу (без .dt)"
else
    echo "1) Загрузить из интернета (mlgo.ru)"
    echo "2) Создать ПУСТУЮ базу (без .dt)"
    COUNT=0
fi

read -p "Ваш выбор: " CHOICE

# 4. Логика выбора файла
RESTORE_CMD=""
if [ "$CHOICE" -le "$COUNT" ] && [ $COUNT -gt 0 ]; then
    DT_PATH=$(realpath "${FILES[$((CHOICE-1))]}")
    RESTORE_CMD="--restore=$DT_PATH"
elif [ "$CHOICE" -eq $((COUNT+1)) ]; then
    DT_URL="http://mlgo.ru"
    read -p "URL [Enter для $DT_URL]: " USER_URL
    DT_URL=${USER_URL:-$DEFAULT_URL}
    wget -q --show-progress -O /tmp/temp.dt "$DT_URL"
    RESTORE_CMD="--restore=/tmp/temp.dt"
fi

# 5. Выполнение ВАШЕЙ команды из скриншота
echo "🚀 Запуск процесса (создание СУБД + загрузка)..."

# Очистка пароля от лишних символов
PG_PASS_CLEAN=$(echo "$PG_PASS" | tr -d '\r\n ')

$IBCMD_PATH infobase create \
    --dbms=PostgreSQL \
    --db-server=localhost \
    --db-name="$DB_NAME" \
    --db-user=postgres \
    --db-pwd="$PG_PASS_CLEAN" \
    --create-database \
    $RESTORE_CMD

if [ $? -eq 0 ]; then
    echo "-----------------------------------------------------"
    echo "✅ УСПЕХ! База '$DB_NAME' создана и загружена."
else
    echo "❌ Ошибка при выполнении ibcmd create."
fi

rm -f /tmp/temp.dt
