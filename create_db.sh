#!/bin/bash
# Интерактивное создание базы данных 1С через RAS и вывод списка

# 1. Поиск пути к утилитам 1С
VER_DIR=$(ls /opt/1cv8/x86_64/ | grep -E "^8\." | head -n 1)
BIN_PATH="/opt/1cv8/x86_64/$VER_DIR"
RAC_PATH="$BIN_PATH/rac"

if [ ! -f "$RAC_PATH" ]; then
    echo "❌ Ошибка: Утилита rac не найдена в $RAC_PATH"
    exit 1
fi

clear
echo "====================================================="
echo "      Создание новой базы 1С (через RAS)"
echo "====================================================="

# 2. Запрос данных
read -p "Введите имя новой базы (на латинице): " DB_NAME
if [ -z "$DB_NAME" ]; then echo "Имя не может быть пустым"; exit 1; fi

read -sp "Введите пароль пользователя СУБД (postgres): " PG_PASS
echo -e "\n"

echo "⏳ Подключение к кластеру и создание базы..."

# 3. Получение ID кластера
CLUSTER_ID=$($RAC_PATH cluster list | grep cluster | awk '{print $3}')

if [ -z "$CLUSTER_ID" ]; then
    echo "❌ Ошибка: Не удалось получить ID кластера. Проверьте, запущен ли RAS."
    exit 1;
fi

# 4. Выполнение команды создания
$RAC_PATH infobase --cluster=$CLUSTER_ID create \
--name="$DB_NAME" \
--dbms=PostgreSQL \
--db-server=localhost \
--db-name="$DB_NAME" \
--db-user=postgres \
--db-pwd="$PG_PASS" \
--locale=ru \
--create-database > 
--license-distribution=allow > /dev/null

if [ $? -eq 0 ]; then
    echo "-----------------------------------------------------"
    echo "✅ УСПЕХ! База '$DB_NAME' создана."
    echo "-----------------------------------------------------"
    
    # 5. Переход в директорию и вывод списка всех баз
    echo "📂 Переход в директорию: $BIN_PATH"
    cd "$BIN_PATH" || exit
    
    echo "📋 Список существующих информационных баз:"
    echo "-----------------------------------------------------"
    # Команда выводит сводный список всех баз в кластере
    $RAC_PATH infobase --cluster=$CLUSTER_ID summary list
    echo "-----------------------------------------------------"
else
    echo "❌ Ошибка при создании базы. Проверьте пароль или наличие базы с таким именем."
    exit 1
fi
