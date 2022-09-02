# script.postgresql.backup
Backup a postgresql server via pg_dumpall to a Google Cloud Storage bucket

# Usage
op.backup <bucket-name>

# Environment
Must be ran from a virtual machine where its service account has write to the specified bucket
