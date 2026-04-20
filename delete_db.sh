cat << 'EOF' > delete_db.sh
#!/bin/bash

# 1. Path setup
VER_DIR=$(ls /opt/1cv8/x86_64/ | grep -E "^8\." | head -n 1)
BIN_PATH="/opt/1cv8/x86_64/$VER_DIR"
RAC_PATH="$BIN_PATH/rac"

# 2. Get Cluster ID
CLUSTER_ID=$($RAC_PATH cluster list localhost:1545 | grep cluster | awk '{print $3}')

if [ -z "$CLUSTER_ID" ]; then
    echo "❌ Error: Could not find Cluster ID. Is RAS running?"
    exit 1
fi

clear
echo "====================================================="
echo "      1C:Enterprise Database Cleanup Tool"
echo "====================================================="

# 3. Get list of bases and store in array
mapfile -t IB_NAMES < <($RAC_PATH infobase --cluster=$CLUSTER_ID summary list localhost:1545 | grep "name" | awk '{print $3}')
mapfile -t IB_IDS < <($RAC_PATH infobase --cluster=$CLUSTER_ID summary list localhost:1545 | grep "infobase" | awk '{print $3}')

if [ ${#IB_NAMES[@]} -eq 0 ]; then
    echo "📭 No databases found in this cluster."
    exit 0
fi

# 4. Show the list to the user
echo "Found ${#IB_NAMES[@]} databases:"
for i in "${!IB_NAMES[@]}"; do
    echo "$((i+1))) ${IB_NAMES[$i]}"
done
echo "q) Quit"
echo "-----------------------------------------------------"

read -p "Select a database number to DELETE (or 'q'): " CHOICE

if [[ "$CHOICE" == "q" ]]; then
    exit 0
fi

# Validate input
if [[ "$CHOICE" -gt 0 && "$CHOICE" -le "${#IB_NAMES[@]}" ]]; then
    INDEX=$((CHOICE-1))
    TARGET_NAME=${IB_NAMES[$INDEX]}
    TARGET_ID=${IB_IDS[$INDEX]}

    echo "⚠️  WARNING: You are about to delete '$TARGET_NAME' ($TARGET_ID)"
    read -p "Are you sure? This will also wipe PostgreSQL data! (y/N): " CONFIRM

    if [[ "$CONFIRM" == "y" || "$CONFIRM" == "Y" ]]; then
        echo "⏳ Deleting..."
        $RAC_PATH infobase --cluster=$CLUSTER_ID drop --infobase=$TARGET_ID --drop-database localhost:1545
        if [ $? -eq 0 ]; then
            echo "✅ SUCCESS: Database '$TARGET_NAME' has been removed."
        else
            echo "❌ Error occurred during deletion."
        fi
    else
        echo "🚫 Deletion cancelled."
    fi
else
    echo "❌ Invalid selection."
fi
EOF

chmod +x delete_db.sh
