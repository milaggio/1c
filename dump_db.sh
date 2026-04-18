#!/bin/bash
# Скрипт импорта данных (.dt) в существующую базу 1С через ibcmd

# 1. Поиск путей
VER_DIR=$(ls /opt/1cv8/x86_64/ | grep -E "^8\." | head -n 1)
BIN_PATH="/opt/1cv8/x86_64/$VER_DIR"
RAC_PATH="$BIN_PATH/rac"
IBCMD_PATH="$BIN_PATH/ibcmd"

if [ ! -f "$IBCMD_PATH" ]; then
    echo "❌ Ошибка: Утилиты 1С не найдены."
    exit 1
fi

clear
echo "====================================================="
echo "      Импорт данных (.dt) в базу 1С"
echo "====================================================="

# 2. Получение списка баз для выбора
CLUSTER_ID=$($RAC_PATH cluster list | grep cluster | awk '{print $3}')
mapfile -t INFOBASE_NAMES < <($RAC_PATH infobase --cluster=$CLUSTER_ID summary list | grep "name" | awk -F ":" '{print $2}' | tr -d ' "')

if [ ${#INFOBASE_NAMES[@]} -eq 0 ]; then
    echo "❌ Информационные базы не найдены. Сначала создайте базу."
    exit 1
fi

echo "Выберите базу, в которую нужно загрузить данные:"
for i in "${!INFOBASE_NAMES[@]}"; do
    echo "$((i+1))) ${INFOBASE_NAMES[$i]}"
done
read -p "Ваш выбор (1-${#INFOBASE_NAMES[@]}): " DB_NUM
SELECTED_DB=${INFOBASE_NAMES[$((DB_NUM-1))]}

if [ -z "$SELECTED_DB" ]; then echo "❌ Неверный выбор."; exit 1; fi

# 3. Запрос пароля СУБД
read -sp "Введите пароль пользователя БД 'postgres': " PG_PASS
echo -e "\n"

# 4. Выбор источника .dt (Локально или Сеть)
echo "-----------------------------------------------------"
echo "Выберите источник файла .dt:"
mapfile -t LOCAL_FILES < <(ls *.dt 2>/dev/null)
COUNT=${#LOCAL_FILES[@]}

if [ $COUNT -gt 0 ]; then
    for i in "${!LOCAL_FILES[@]}"; do
        echo "$((i+1))) Локальный файл: ${LOCAL_FILES[$i]}"
    done
    WEB_CHOICE=$((COUNT+1))
    echo "$WEB_CHOICE) Загрузить из интернета (mlgo.ru)"
else
    echo "(!) Локальных .dt файлов не найдено."
    WEB_CHOICE=1
    echo "$WEB_CHOICE) Загрузить из интернета (mlgo.ru)"
fi

read -p "Ваш выбор: " SOURCE_CHOICE

# 5. Обработка выбора файла
DT_FILE=""
if [ "$SOURCE_CHOICE" -le "$COUNT" ] && [ $COUNT -gt 0 ]; then
    # Получаем АБСОЛЮТНЫЙ путь к локальному файлу
    SELECTED_FILENAME="${LOCAL_FILES[$((SOURCE_CHOICE-1))]}"
    DT_FILE="$(pwd)/$SELECTED_FILENAME"
elif [ "$SOURCE_CHOICE" -eq "$WEB_CHOICE" ]; then
    DEFAULT_URL="http://mlgo.ru"
    read -p "Введите URL [Enter для $DEFAULT_URL]: " USER_URL
    DT_URL=${USER_URL:-$DEFAULT_URL}
    DT_FILE="/tmp/restore.dt"
    echo "⬇️ Загрузка..."
    wget -q --show-progress -O "$DT_FILE" "$DT_URL"
else
    echo "❌ Отмена."; exit 1
fi


# 6. Запуск импорта
echo "⚙️  Восстановление данных в базу '$SELECTED_DB'..."
echo "📂 Файл: $DT_FILE"

$IBCMD_PATH infobase restore \
    --dbms PostgreSQL \
    --db-server localhost \
    --db-name "$SELECTED_DB" \
    --db-user postgres \
    --db-pwd "$PG_PASS" \
    --file "$DT_FILE"


if [ $? -eq 0 ]; then
    echo "✅ Готово! Данные успешно загружены."
else
    echo "❌ Ошибка импорта через ibcmd."
fi

[[ "$DT_FILE" == "/tmp/restore.dt" ]] && rm -f "$DT_FILE"
