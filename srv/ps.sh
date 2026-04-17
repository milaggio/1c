#!/bin/bash
# Установка PostgreSQL 17 для 1С по точной инструкции PostgresPro

if [ "$EUID" -ne 0 ]; then
  echo "❌ Ошибка: Запустите с sudo"
  exit 1
fi

echo "=== Установка PostgreSQL 17 для 1С ==="

# 1. Ваша оригинальная инструкция
wget https://repo.postgrespro.ru/1c/1c-17/keys/pgpro-repo-add.sh
sudo sh pgpro-repo-add.sh
sudo apt-get install -y postgrespro-1c-17

# 2. Установка пароля для пользователя postgres
# (Необходимо для подключения сервера 1С к базе данных)
echo "-----------------------------------------------------"
read -sp "Придумайте пароль для пользователя БД 'postgres': " PG_PASS
echo
sudo -u postgres /opt/pgpro/1c-17/bin/psql -c "ALTER USER postgres WITH PASSWORD '$PG_PASS';"

echo "-----------------------------------------------------"
echo "✅ PostgreSQL 17 установлен и готов к работе!"
systemctl status postgrespro-1c-17 --no-pager

# Удаление временного файла
rm -f pgpro-repo-add.sh
