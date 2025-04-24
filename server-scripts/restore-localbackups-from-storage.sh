#!/bin/bash

# Configuration
BACKUP_DIR="./sql-backups"
STORAGE_BUCKET="database-backups"
NUM_BACKUPS_TO_RESTORE=3

# Supabase configuration
SUPABASE_URL="your-project-url"
SUPABASE_KEY="your-service-role-key"  # Use service role key for storage access

# Function to get list of files in Supabase storage
get_storage_files() {
    curl -s -X GET \
        -H "Authorization: Bearer $SUPABASE_KEY" \
        -H "apikey: $SUPABASE_KEY" \
        "$SUPABASE_URL/storage/v1/object/list/$STORAGE_BUCKET" | \
        jq -r '.[].name'
}

# Function to download file from Supabase storage
download_from_storage() {
    local filename=$1
    local output_file="$BACKUP_DIR/$filename"
    
    curl -s -X GET \
        -H "Authorization: Bearer $SUPABASE_KEY" \
        -H "apikey: $SUPABASE_KEY" \
        "$SUPABASE_URL/storage/v1/object/$STORAGE_BUCKET/$filename" \
        -o "$output_file"
    
    # Verify download was successful
    if [ $? -eq 0 ] && [ -f "$output_file" ]; then
        echo "Successfully downloaded: $filename"
        return 0
    else
        echo "Failed to download: $filename"
        return 1
    fi
}

# Function to check if file exists locally
file_exists_locally() {
    local filename=$1
    [ -f "$BACKUP_DIR/$filename" ]
}

# Main script
echo "Starting restore process..."

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Get list of files in storage and sort by date (newest first)
STORAGE_FILES=$(get_storage_files | sort -r | head -n $NUM_BACKUPS_TO_RESTORE)

# Restore backups that don't exist locally
for file in $STORAGE_FILES; do
    if ! file_exists_locally "$file"; then
        echo "Restoring backup: $file"
        download_from_storage "$file"
    else
        echo "Backup already exists locally: $file"
    fi
done

echo "Restore process completed"
