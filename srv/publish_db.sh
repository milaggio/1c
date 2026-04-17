#!/bin/bash
# Интерактивная публикация базы 1С на Apache2

# 1. Поиск путей
VER_DIR=$(ls /opt/1cv8/x86_64/ | grep -E "^8\." | head -n 1)
BIN_PATH="/opt/1cv8/x86_64/$VER_DIR"
RAC_PATH="$BIN_PATH/rac"
WEBINST_PATH="$BIN_PATH/webinst"

if [ ! -f "$WEBINST_PATH" ]; then
    echo "❌ Ошибка: Утилита webinst не найдена."
    exit 1
fi

clear
echo "====================================================="
echo "      Публикация базы 1С на веб-сервере"
echo "====================================================="

# 2. Получение ID кластера и списка баз
CLUSTER_ID=$($RAC_PATH cluster list | grep cluster | awk '{print $3}')
mapfile -t INFOBASE_NAMES < <($RAC_PATH infobase --cluster=$CLUSTER_ID summary list | grep "name" | awk -F ":" '{print $2}' | tr -d ' "')

if [ ${#INFOBASE_NAMES[@]} -eq 0 ]; then
    echo "❌ Информационные базы не найдены."
    exit 1
fi

# 3. Выбор базы пользователем
echo "Выберите базу для публикации:"
for i in "${!INFOBASE_NAMES[@]}"; do
    echo "$((i+1))) ${INFOBASE_NAMES[$i]}"
done

read -p "Введите номер (1-${#INFOBASE_NAMES[@]}): " DB_NUM
SELECTED_DB=${INFOBASE_NAMES[$((DB_NUM-1))]}

if [ -z "$SELECTED_DB" ]; then
    echo "❌ Неверный выбор."
    exit 1
fi

echo "🚀 Публикация базы '$SELECTED_DB'..."

# 4. Создание каталога публикации и сама публикация
WEB_DIR="/var/www/$SELECTED_DB"
mkdir -p "$WEB_DIR"
chown -R www-data:www-data "$WEB_DIR"

sudo "$WEBINST_PATH" \
  -publish \
  -apache24 \
  -wsdir "$SELECTED_DB" \
  -dir "$WEB_DIR" \
  -connstr "Srvr=localhost;Ref=$SELECTED_DB;" \
  -confpath /etc/apache2/apache2.conf

# 5. Перезапуск Apache
echo "Перезапуск Apache..."
systemctl restart apache2

echo "-----------------------------------------------------"
echo "✅ ГОТОВО! База '$SELECTED_DB' опубликована."
echo "Адрес: http://$(hostname -I | awk '{print $1}')/$SELECTED_DB"
echo "-----------------------------------------------------"
