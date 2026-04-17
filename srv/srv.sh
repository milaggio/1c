#!/bin/bash

# Проверка запуска через sudo
if [ "$EUID" -ne 0 ]; then
  echo "❌ Ошибка: Запустите скрипт с sudo (sudo ./install/server.sh)"
  exit 1
fi

DEFAULT_URL="repo.mlgo.ru/1c/srv/latest.zip"
ARCHIVE_NAME="latest.zip"
TMP_DIR="/tmp/1c_install"

clear
echo "====================================================="
echo "   Установочка 1С 8.3 + Apache 2 + RAS + GIT (Debian 12)"
echo "====================================================="

# 1. Система (Локаль, утилиты, Git и Apache)
echo "[1/5] Подготовка системы..."
apt update > /dev/null

echo "  > Установка локалей, vim, wget, unzip и git..."
# Добавлен git в список установки
apt install -y locales vim unzip wget git apache2 > /dev/null

# Настройка Git (чтобы сервер знал "кто" он при обновлениях)
git config --global user.name "1C-Installer"
git config --global user.email "admin@mlgo.ru"
# Настройка, чтобы git pull не ругался на разные ветки
git config --global pull.rebase false

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

if [ -z "$CHOICE" ]; then CHOICE=3; fi

case $CHOICE in
    1) read -p "Введите URL: " USER_URL; SOURCE_URL=$USER_URL; MODE="download" ;;
    2) [ -f "./$ARCHIVE_NAME" ] && MODE="local" || { echo "❌ Файл не найден!"; exit 1; } ;;
    3) SOURCE_URL=$DEFAULT_URL; MODE="download" ;;
    *) echo "❌ Неверный выбор."; exit 1 ;;
esac

# 3. Подготовка и загрузка
mkdir -p $TMP_DIR && rm -rf $TMP_DIR/*
if [ "$MODE" == "download" ]; then
    [[ $SOURCE_URL != http* ]] && SOURCE_URL="http://$SOURCE_URL"
    echo "  > Загрузка дистрибутива..."
    wget -q --show-progress -O "$TMP_DIR/$ARCHIVE_NAME" "$SOURCE_URL" || exit 1
else
    echo "  > Использование локального файла..."
    cp "./$ARCHIVE_NAME" "$TMP_DIR/"
fi

echo "  > Распаковка пакетов..."
unzip -q -o "$TMP_DIR/$ARCHIVE_NAME" -d "$TMP_DIR/extracted"
cd "$TMP_DIR/extracted"

# 4. Установка 1С (Исключаем NLS и CRS)
echo "[3/5] Установка пакетов 1С (без NLS и CRS)..."
DEBS=$(ls *.deb 2>/dev/null | grep -v -E "nls|crs" | sed "s|^|./|")
if [ -n "$DEBS" ]; then
    apt install -y $DEBS
else
    echo "❌ Пакеты не найдены!"; exit 1
fi

# 5. Службы 1С и RAS
echo "[4/5] Активация служб 1С и RAS..."
VER_DIR=$(ls /opt/1cv8/x86_64/ | grep -E "^8\." | head -n 1)

if [ -n "$VER_DIR" ]; then
    UNIT_NAME="srv1cv8-$VER_DIR@default"
    RAS_UNIT="ras-$VER_DIR.service"
    
    # Регистрация основного сервера
    systemctl link "/opt/1cv8/x86_64/$VER_DIR/srv1cv8-$VER_DIR@.service" > /dev/null 2>&1
    systemctl enable "$UNIT_NAME" > /dev/null 2>&1
    systemctl restart "$UNIT_NAME"

    # Регистрация сервера администрирования
    systemctl link "/opt/1cv8/x86_64/$VER_DIR/ras-$VER_DIR.service" > /dev/null 2>&1
    systemctl enable "$RAS_UNIT" > /dev/null 2>&1
    systemctl restart "$RAS_UNIT"
    
    echo -e "\n✅ Установка 1С, Apache, RAS и Git завершена успешно!"
    echo "-----------------------------------------------------"
    systemctl status "$UNIT_NAME" --no-pager
    echo "-----------------------------------------------------"
    systemctl status "$RAS_UNIT" --no-pager
    echo "-----------------------------------------------------"
    
    echo "Список активных процессов 1С:"
    ps aux | grep /opt/1cv8/ | grep -v grep
else
    echo "❌ Ошибка: Версия 1С не обнаружена в /opt/1cv8/"
fi

# 6. Очистка
rm -rf $TMP_DIR

