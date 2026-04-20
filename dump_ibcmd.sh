#!/bin/bash
# Выгрузка базы 1С в формат .dt через ibcmd

# 1. Поиск путей
VER_DIR=$(ls /opt/1cv8/x86_64/ | grep -E "^8\." | head -n 1)
BIN_PATH="/opt/1cv8/x86_64/$VER_DIR"
RAC_PATH="$BIN_PATH/rac"
IBCMD_PATH="$BIN_PATH/ibcmd"

if [ ! -f "$IBCMD_PATH" ]; then
    echo "❌ Ошибка: Утилита ibcmd не найдена."
    exit 1
fi

clear
echo "====================================================="
echo "      Выгрузка базы 1С в архив (.dt)"
echo "====================================================="

# 2. Получение списка баз для выбора
CLUSTER_ID=$($RAC_PATH cluster list | grep cluster | awk '{print $3}')
mapfile -t INFOBASE_NAMES < <($RAC_PATH infobase --cluster=$CLUSTER_ID summary list | grep "name" | awk -F ":" '{print $2}' | tr -d ' "')

if [ ${#INFOBASE_NAMES[@]} -eq 0 ]; then
    echo "❌ Информационные базы не найдены."
    exit 1
fi

echo "Выберите базу для выгрузки:"
for i in "${!INFOBASE_NAMES[@]}"; do
    echo "$((i+1))) ${INFOBASE_NAMES[$i]}"
done
read -p "Ваш выбор (1-${#INFOBASE_NAMES[@]}): " DB_NUM
SELECTED_DB=${INFOBASE_NAMES[$((DB_NUM-1))]}

if [ -z "$SELECTED_DB" ]; then echo "❌ Неверный выбор."; exit 1; fi

# 3. Запрос пароля СУБД
read -sp "Введите пароль пользователя БД 'postgres': " PG_PASS
echo -e "\n"

# 4. Формирование имени файла (ИмяБазы_ГГГГ-ММ-ДД_ЧЧ-ММ.dt)
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M")
DUMP_FILENAME="${SELECTED_DB}_${TIMESTAMP}.dt"
# Сохраняем в домашнюю папку, чтобы было легко найти
DUMP_PATH="$(realpath ~)/$DUMP_FILENAME"

echo "⚙️  Запуск выгрузки базы '$SELECTED_DB'..."
echo "📂 Файл назначения: $DUMP_PATH"

# 5. Выполнение выгрузки через ibcmd dump
# Используем проверенный синтаксис (параметры СУБД + путь в конце)
$IBCMD_PATH infobase dump \
    --dbms PostgreSQL \
    --db-server localhost \
    --db-name "$SELECTED_DB" \
    --db-user postgres \
    --db-pwd "$PG_PASS" \
    "$DUMP_PATH"

if [ $? -eq 0 ]; then
    echo "-----------------------------------------------------"
    echo "✅ УСПЕХ! База выгружена в файл:"
    echo "$DUMP_PATH"
    echo "-----------------------------------------------------"
    ls -lh "$DUMP_PATH"
else
    echo "-----------------------------------------------------"
    echo "❌ Ошибка выгрузки через ibcmd."
fi
