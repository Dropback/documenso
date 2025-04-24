# Configuration
BACKUP_DIR="./sql-backups"
MAX_SIZE_GB=10
MAX_SIZE_BYTES=$((MAX_SIZE_GB * 1024 * 1024 * 1024))

if [ "$PWD" != "$HOME/documenso" ]; then
  cd "$HOME/documenso"
fi

if [ ! -d "./sql-backups" ]; then
  mkdir ./sql-backups
fi

# Function to get directory size in bytes
get_dir_size() {
    du -sb "$BACKUP_DIR" | cut -f1
}

# Function to delete oldest backup
delete_oldest_backup() {
    oldest_file=$(find "$BACKUP_DIR" -type f -name "*.sql" -printf '%T+ %p\n' | sort | head -n1 | cut -d' ' -f2-)
    if [ -n "$oldest_file" ]; then
        echo "Deleting oldest backup: $oldest_file"
        rm "$oldest_file"
    fi
}

# Check size before backup
while [ $(get_dir_size) -gt $MAX_SIZE_BYTES ]; do
    echo "Backup directory size exceeds ${MAX_SIZE_GB}GB, deleting oldest backup..."
    delete_oldest_backup
done

# Your existing backup command
BACKUP_FILE="$BACKUP_DIR/backup_$(date +%Y%m%d_%H%M%S).sql"
docker exec -t documenso-production_database_1 pg_dumpall -c -U your-db-user | gzip > $BACKUP_FILE

# Check size after backup
while [ $(get_dir_size) -gt $MAX_SIZE_BYTES ]; do
    echo "Backup directory size exceeds ${MAX_SIZE_GB}GB after new backup, deleting oldest backup..."
    delete_oldest_backup
done

echo "Backup completed and size limit maintained"