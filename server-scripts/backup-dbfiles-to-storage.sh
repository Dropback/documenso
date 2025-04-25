#!/bin/bash


# TODO: MAKE THIS SCRIPT WORK!!

# Load environment variables from .env file if it exists
if [ -f .env ]; then
    echo "Loading environment variables from .env file..."
    export $(grep -v '^#' .env | xargs)
fi

# Configuration
BACKUP_DIR="/root/documenso/sql-backups"
STORAGE_BUCKET="${SUPABASE_STORAGE_BUCKET:-documenso-database-backups}"
RETENTION_DAYS=7

# Supabase configuration
S3_ENDPOINT="${SUPABASE_S3_ENDPOINT}"
S3_ACCESS_KEY="${SUPABASE_S3_ACCESS_KEY}"
S3_SECRET_KEY="${SUPABASE_S3_SECRET_KEY}"

# Validate required environment variables
if [ -z "$S3_ENDPOINT" ] || [ -z "$S3_ACCESS_KEY" ] || [ -z "$S3_SECRET_KEY" ]; then
    echo "Error: SUPABASE_S3_ENDPOINT, SUPABASE_S3_ACCESS_KEY, and SUPABASE_S3_SECRET_KEY must be set"
    exit 1
fi

# Function to get list of files in storage
get_storage_files() {
    curl -s -X GET \
        -H "Authorization: Bearer $S3_ACCESS_KEY" \
        "$S3_ENDPOINT/object/list/$STORAGE_BUCKET" | \
        jq -r '.[].name'
}

# Function to upload file to storage
upload_to_storage() {
    local file=$1
    local filename=$(basename "$file")
    local content_type="application/octet-stream"
    
    echo "Uploading file: $filename"
    curl -v -X POST \
        -H "Authorization: Bearer $S3_ACCESS_KEY" \
        -H "Content-Type: $content_type" \
        --data-binary "@$file" \
        "$S3_ENDPOINT/object/$STORAGE_BUCKET/$filename"
}

# Function to delete file from storage
delete_from_storage() {
    local filename=$1
    
    curl -s -X DELETE \
        -H "Authorization: Bearer $S3_ACCESS_KEY" \
        "$S3_ENDPOINT/object/$STORAGE_BUCKET/$filename"
}

# Function to check if file needs backup
needs_backup() {
    local file=$1
    local filename=$(basename "$file")
    
    echo "Checking if file exists in storage: $filename"

    # Check if file exists in storage
    if curl -s -I \
        -H "Authorization: Bearer $S3_ACCESS_KEY" \
        "$S3_ENDPOINT/object/$STORAGE_BUCKET/$filename" | \
        grep -q "200 OK"; then
        
        # Get local and remote file sizes
        local local_size=$(stat -f%z "$file")
        local remote_size=$(curl -s -I \
            -H "Authorization: Bearer $S3_ACCESS_KEY" \
            "$S3_ENDPOINT/object/$STORAGE_BUCKET/$filename" | \
            grep -i "content-length" | awk '{print $2}' | tr -d '\r')
        
        echo "File exists in storage: $filename. Local size: $local_size, Remote size: $remote_size"
        # If sizes differ, file needs backup
        [ "$local_size" != "$remote_size" ]
    else
        echo "File does not exist in storage: $filename"
        # File doesn't exist in storage, needs backup
        true
    fi
}

# Function to cleanup old backups
cleanup_old_backups() {
    local cutoff_date=$(date -d "-${RETENTION_DAYS} days" +%Y%m%d)
    
    get_storage_files | while read -r file; do
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

# Upload new or modified backups in form of .gz files
for file in "$BACKUP_DIR"/*.gz; do
    if [ -f "$file" ] && needs_backup "$file"; then
        echo "Uploading backup: $(basename "$file")"
        upload_to_storage "$file"
    fi
done

# Cleanup old backups
echo "Cleaning up backups older than $RETENTION_DAYS days..."
cleanup_old_backups

echo "Backup process completed"
