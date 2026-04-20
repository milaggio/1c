cat << 'EOF' > clear_license.sh
#!/bin/bash
# Интерактивная очистка кэша программных лицензий в PostgreSQL

clear
echo "====================================================="
echo "   Очистка кэша лицензий 1С в PostgreSQL"
echo "====================================================="

# 1. Запрос параметров подключения
read -p "Введите адрес хоста СУБД [localhost]: " PGHOST
PGHOST=${PGHOST:-localhost}

read -p "Введите имя пользователя СУБД [postgres]: " PGUSER
PGUSER=${PGUSER:-postgres}

read -sp "Введите пароль пользователя $PGUSER: " PGPASSWORD
echo -e "\n"
export PGPASSWORD

# 2. Получение списка баз данных (исключая системные)
echo "⏳ Получение списка баз данных..."
mapfile -t DB_LIST < <(psql -h $PGHOST -U $PGUSER -t -c "SELECT datname FROM pg_database WHERE datname NOT IN ('postgres', 'template0', 'template1');" | sed 's/ //g' | grep -v '^$')

if [ ${#DB_LIST[@]} -eq 0 ]; then
    echo "❌ Базы данных не найдены или ошибка подключения."
    exit 1
fi

# 3. Выбор базы пользователем
echo "Найдены следующие базы:"
for i in "${!DB_LIST[@]}"; do
    echo "$((i+1))) ${DB_LIST[$i]}"
done
echo "a) Очистить во ВСЕХ базах"
echo "q) Выход"
echo "-----------------------------------------------------"

read -p "Выберите номер базы: " CHOICE

if [[ "$CHOICE" == "q" ]]; then
    exit 0
fi

# 4. Логика очистки
clear_db() {
    local db=$1
    echo "🧼 Очистка кэша в базе: $db"
    psql -h $PGHOST -U $PGUSER -d "$db" <<SQL
UPDATE public.files SET datasize=0, binarydata=CAST('' AS bytea) WHERE filename = 'c01b78f6-1525-41b1-9cc1-69e3da58d2ac.pfl';
SQL
    if [ $? -eq 0 ]; then
        echo "✅ Готово."
    else
        echo "❌ Ошибка при работе с базой $db"
    fi
}

if [[ "$CHOICE" == "a" ]]; then
    for db in "${DB_LIST[@]}"; do
        clear_db "$db"
    done
elif [[ "$CHOICE" -gt 0 && "$CHOICE" -le "${#DB_LIST[@]}" ]]; then
    SELECTED_DB=${DB_LIST[$((CHOICE-1))]}
    clear_db "$SELECTED_DB"
else
    echo "❌ Неверный выбор."
    exit 1
fi

echo "-----------------------------------------------------"
echo "🎉 Операция завершена."
echo "💡 Рекомендуется перезапустить сервер 1С: sudo systemctl restart srv1cv83"

# Очищаем пароль из переменных окружения
unset PGPASSWORD
EOF

chmod +x clear_license.sh
