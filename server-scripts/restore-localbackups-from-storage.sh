#!/bin/bash

# TODO: MAKE THIS SCRIPT WORK!!


# Load environment variables from .env file if it exists
if [ -f .env ]; then
    echo "Loading environment variables from .env file..."
    export $(grep -v '^#' .env | xargs)
fi

# Configuration
BACKUP_DIR="./sql-backups"
STORAGE_BUCKET="${SUPABASE_STORAGE_BUCKET:-documenso-database-backups}"
NUM_BACKUPS_TO_RESTORE=3

# Supabase S3 configuration
S3_ENDPOINT="${SUPABASE_S3_ENDPOINT:-https://smztamqokgoertoixwmk.supabase.co/storage/v1/s3}"
S3_ACCESS_KEY="${SUPABASE_S3_ACCESS_KEY}"
S3_SECRET_KEY="${SUPABASE_S3_SECRET_KEY}"
S3_REGION="${SUPABASE_S3_REGION:-us-east-2}"

# Validate required environment variables
if [ -z "$S3_ACCESS_KEY" ] || [ -z "$S3_SECRET_KEY" ]; then
    echo "Error: SUPABASE_S3_ACCESS_KEY and SUPABASE_S3_SECRET_KEY must be set"
    exit 1
fi

# Function to generate S3 signature
generate_signature() {
    local method=$1
    local path=$2
    local date=$3
    local content_type=$4
    
    local string_to_sign="$method\n\n$content_type\n$date\n/$STORAGE_BUCKET$path"
    local signature=$(echo -en "$string_to_sign" | openssl sha1 -hmac "$S3_SECRET_KEY" -binary | base64)
    echo "$signature"
}

# Function to get list of files in S3 storage
get_storage_files() {
    local date=$(date -u +"%a, %d %b %Y %H:%M:%S GMT")
    local signature=$(generate_signature "GET" "" "$date" "")
    
    curl -s -X GET \
        -H "Date: $date" \
        -H "Authorization: AWS $S3_ACCESS_KEY:$signature" \
        "$S3_ENDPOINT/$STORAGE_BUCKET" | \
        xmllint --xpath "//Key/text()" - 2>/dev/null
}

# Function to download file from S3 storage
download_from_storage() {
    local filename=$1
    local output_file="$BACKUP_DIR/$filename"
    local date=$(date -u +"%a, %d %b %Y %H:%M:%S GMT")
    local signature=$(generate_signature "GET" "/$filename" "$date" "")
    
    curl -s -X GET \
        -H "Date: $date" \
        -H "Authorization: AWS $S3_ACCESS_KEY:$signature" \
        "$S3_ENDPOINT/$STORAGE_BUCKET/$filename" \
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
