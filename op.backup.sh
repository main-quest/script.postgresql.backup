#!/bin/bash

# Postgres Backup script to Google Cloud bucket

set -e

echo "op.backup"

BACKUP_FILE_NAME="latest.sql"
OS_USER="postgres"
OS_USER_GROUP="postgres"
BACKUP_BUCKET_NAME="${1?Expecting the destination bucket name as the 1st arg}"

wd="$(mktemp -d)"
cd "$wd"
echo "Working directory: $wd"

# Commented: only postgres needs access to this
# chmod 777 "$wd"
echo "Setting '$OS_USER' as owner of '$wd'"
chown "$OS_USER":"$OS_USER_GROUP" "$wd"

local_file="$BACKUP_FILE_NAME"

echo "Create local backup file from entire cluster via pg_dumpall at $wd/$local_file"
# Commented: if running on Alpine, sudo is not available and actually not needed
# sudo -u "$DB_USER" pg_dumpall --file="$local_file"
su "$OS_USER" -c "cd '$wd' && pg_dumpall --clean --if-exists --file='$local_file'"

timestamped_file="$(date -u +"%d-%m-%Y %H-%M-%S").sql"

echo "Retrieving default service account token"
# Thanks https://medium.com/@sachin.d.shinde/docker-compose-in-container-optimized-os-159b12e3d117
TOKEN=$(curl --fail "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" -H "Metadata-Flavor: Google")
TOKEN=$(echo "$TOKEN" | grep --extended-regexp --only-matching "(ya29.[0-9a-zA-Z._-]*)")
gs_copy(){
    local dest_path_in_bucket="$1"
    echo "Uploading '$local_file' to 'gs://$BACKUP_BUCKET_NAME/$dest_path_in_bucket' via REST"

    # Commented: I couldn't get '--data-urlencode' to work
    # # Commented: Using curl's the more-convenient '--data-urlencode'
    # # # https://stackoverflow.com/a/34407620
    # # dest_path_urlencoded=$(printf %s "$dest_path_in_bucket"|jq -sRr @uri)
    # dest_path_urlencoded="$dest_path_in_bucket"
    dest_path_urlencoded=$(printf %s "$dest_path_in_bucket"|jq -sRr @uri)

        # -H "Content-Type: application/octet-stream" \
    curl -X POST \
        --fail \
        -H "Authorization: Bearer $TOKEN" \
        --data-binary "@$local_file" \
        "https://storage.googleapis.com/upload/storage/v1/b/$BACKUP_BUCKET_NAME/o?uploadType=media&name=$dest_path_urlencoded"
}

gs_copy "backup/$timestamped_file"
gs_copy "backup/$local_file"

echo "Done!"
