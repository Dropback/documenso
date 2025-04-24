#!/bin/bash

# Configuration
BACKUP_DIR="./sql-backups"
STORAGE_BUCKET="database-backups"
RETENTION_DAYS=7

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

# Function to upload file to Supabase storage
upload_to_storage() {
    local file=$1
    local filename=$(basename "$file")
    
    curl -s -X POST \
        -H "Authorization: Bearer $SUPABASE_KEY" \
        -H "apikey: $SUPABASE_KEY" \
        -H "Content-Type: application/octet-stream" \
        --data-binary "@$file" \
        "$SUPABASE_URL/storage/v1/object/$STORAGE_BUCKET/$filename"
}

# Function to delete file from Supabase storage
delete_from_storage() {
    local filename=$1
    
    curl -s -X DELETE \
        -H "Authorization: Bearer $SUPABASE_KEY" \
        -H "apikey: $SUPABASE_KEY" \
        "$SUPABASE_URL/storage/v1/object/$STORAGE_BUCKET/$filename"
}

# Function to check if file needs backup
needs_backup() {
    local file=$1
    local filename=$(basename "$file")
    
    # Check if file exists in storage
    if echo "$STORAGE_FILES" | grep -q "^$filename$"; then
        # Get local and remote file sizes
        local local_size=$(stat -f%z "$file")
        local remote_size=$(curl -s -I \
            -H "Authorization: Bearer $SUPABASE_KEY" \
            -H "apikey: $SUPABASE_KEY" \
            "$SUPABASE_URL/storage/v1/object/$STORAGE_BUCKET/$filename" | \
            grep -i "content-length" | awk '{print $2}' | tr -d '\r')
        
        # If sizes differ, file needs backup
        [ "$local_size" != "$remote_size" ]
    else
        # File doesn't exist in storage, needs backup
        true
    fi
}

# Function to cleanup old backups
cleanup_old_backups() {
    local cutoff_date=$(date -v-${RETENTION_DAYS}d +%Y%m%d)
    
    echo "$STORAGE_FILES" | while read -r file; do
        # Extract date from filename (assuming format backup_YYYYMMDD_HHMMSS.sql)
        local file_date=$(echo "$file" | grep -oE '[0-9]{8}')
        
        if [ -n "$file_date" ] && [ "$file_date" -lt "$cutoff_date" ]; then
            echo "Deleting old backup: $file"
            delete_from_storage "$file"
        fi
    done
}

# Main script
echo "Starting backup process..."

# Get list of files in storage
STORAGE_FILES=$(get_storage_files)

# Upload new or modified backups
for file in "$BACKUP_DIR"/*.sql; do
    if [ -f "$file" ] && needs_backup "$file"; then
        echo "Uploading backup: $(basename "$file")"
        upload_to_storage "$file"
    fi
done

# Cleanup old backups
echo "Cleaning up backups older than $RETENTION_DAYS days..."
cleanup_old_backups

echo "Backup process completed"
