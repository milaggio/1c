#!/bin/bash

# Проверка запуска через sudo
if [ "$EUID" -ne 0 ]; then
  echo "❌ Ошибка: Запустите скрипт с sudo (sudo ./install_1c.sh)"
  exit 1
fi

DEFAULT_URL="repo.mlgo.ru/1c/srv/latest.zip"
ARCHIVE_NAME="latest.zip"
TMP_DIR="/tmp/1c_install"

clear
echo "====================================================="
echo "   Установка 1С 8.3 + Apache 2 + RAS (Debian 12)"
echo "====================================================="

# 1. Система (Локаль и утилиты)
echo "[1/5] Подготовка системы..."
apt update > /dev/null

echo "  > Установка локалей и системных утилит (vim, unzip, wget)..."
apt install -y locales vim unzip wget > /dev/null

echo "  > Установка веб-сервера Apache2..."
apt install -y apache2 > /dev/null

unset LANGUAGE
unset LC_ALL

echo "  > Генерация русской локали..."
sed -i 's/^# ru_RU.UTF-8 UTF-8/ru_RU.UTF-8 UTF-8/' /etc/locale.gen
locale-gen ru_RU.UTF-8 > /dev/null

update-locale LANG=ru_RU.UTF-8 LC_ALL=ru_RU.UTF-8 LANGUAGE=ru_RU.UTF-8
export LANG=ru_RU.UTF-8
export LC_ALL=ru_RU.UTF-8

# 2. Выбор источника
echo -e "\n[2/5] Выберите источник дистрибутива:"
echo "1) Ввод URL"
echo "2) Локальный файл ($ARCHIVE_NAME)"
echo "3) По умолчанию ($DEFAULT_URL) [ENTER]"
read -p "Ваш выбор (1-3): " CHOICE

if [ -z "$CHOICE" ]; then
    CHOICE=3
fi

case $CHOICE in
    1) read -p "Введите URL: " USER_URL; SOURCE_URL=$USER_URL; MODE="download" ;;
    2) [ -f "./$ARCHIVE_NAME" ] && MODE="local" || { echo "❌ Файл не найден!"; exit 1; } ;;
    3) SOURCE_URL=$DEFAULT_URL; MODE="download" ;;
    *) echo "❌ Неверный выбор."; exit 1 ;;
esac

# 3. Подготовка
mkdir -p $TMP_DIR && rm -rf $TMP_DIR/*
if [ "$MODE" == "download" ]; then
    [[ $SOURCE_URL != http* ]] && SOURCE_URL="http://$SOURCE_URL"
    echo "  > Загрузка дистрибутива..."
    wget -q --show-progress -O "$TMP_DIR/$ARCHIVE_NAME" "$SOURCE_URL" || exit 1
else
    echo "  > Копирование локального файла..."
    cp "./$ARCHIVE_NAME" "$TMP_DIR/"
fi

echo "  > Распаковка пакетов..."
unzip -q -o "$TMP_DIR/$ARCHIVE_NAME" -d "$TMP_DIR/extracted"
cd "$TMP_DIR/extracted"

# 4. Установка 1С
echo "[3/5] Установка пакетов 1С (без NLS и CRS)..."
DEBS=$(ls *.deb 2>/dev/null | grep -v -E "nls|crs" | sed "s|^|./|")

if [ -n "$DEBS" ]; then
    apt install -y $DEBS
else
    echo "❌ Пакеты не найдены!"; exit 1
fi

# 5. Служба, RAS и Статус
echo "[4/5] Активация служб 1С и RAS..."
VER_DIR=$(ls /opt/1cv8/x86_64/ | grep -E "^8\." | head -n 1)

if [ -n "$VER_DIR" ]; then
    # Настройка основного сервера
    SERVICE_PATH="/opt/1cv8/x86_64/$VER_DIR/srv1cv8-$VER_DIR@.service"
    UNIT_NAME="srv1cv8-$VER_DIR@default"
    
    systemctl link "$SERVICE_PATH" > /dev/null 2>&1
    systemctl enable "$UNIT_NAME" > /dev/null 2>&1
    systemctl restart "$UNIT_NAME"

    # Настройка RAS
    echo "  > Активация сервера администрирования (RAS)..."
    RAS_PATH="/opt/1cv8/x86_64/$VER_DIR/ras-$VER_DIR.service"
    RAS_UNIT="ras-$VER_DIR.service"
    
    systemctl link "$RAS_PATH" > /dev/null 2>&1
    systemctl enable "$RAS_UNIT" > /dev/null 2>&1
    systemctl restart "$RAS_UNIT"
    
    echo -e "\n✅ Установка 1С, Apache и RAS завершена!"
    echo "-----------------------------------------------------"
    systemctl status "$UNIT_NAME" --no-pager
    echo "-----------------------------------------------------"
    systemctl status "$RAS_UNIT" --no-pager
    echo "-----------------------------------------------------"
    
    echo "Список активных процессов (включая ras):"
    ps aux | grep /opt/1cv8/ | grep -v grep
else
    echo "❌ Ошибка: Версия 1С не обнаружена в /opt/1cv8/"
fi

# 6. Очистка
rm -rf $TMP_DIR
