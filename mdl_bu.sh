#!/bin/bash

# Load configuration variables from mdl_bu.conf
CONFIG_FILE='mdl_bu.conf'

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file $CONFIG_FILE not found. Please create it based on mdl_bu.conf.template."
    exit 1
fi

# The 'source' command reads and executes the content of the specified file
# It makes the variables and functions defined in mdl_bu.conf available in this script
# shellcheck source=/dev/null
source "$CONFIG_FILE"

# Check if NUM_BACKUPS_TO_KEEP is set
if [ -z "$NUM_BACKUPS_TO_KEEP" ]; then
    echo "Error: NUM_BACKUPS_TO_KEEP is not set in $CONFIG_FILE. Please set it and try again."
    exit 1
fi

# Function to check if a variable is set
check_variable() {
    local var_name="$1"
    local var_value="$2"
    if [ -z "$var_value" ]; then
        log_message "Error: $var_name is not set. Please check the $CONFIG_FILE file."
        exit 1
    fi
}

# Function to log messages to a specified log file
log_message() {
    local log_msg="$1"
    local log_file
    log_file="$BACKUP_DIR/${SERVICE_NAME}_backup_log_$(date +'%Y%m%d%H%M%S').txt"
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $log_msg" >> "$log_file"
    
    # Check if script is running interactively
    if [ -t 1 ]; then
        echo "$log_msg"
    fi
}

# Function to verify that backup files are non-empty
verify_backup() {
    local file="$1"
    if [ ! -s "$file" ]; then
        log_message "Error: Backup file $file is empty or not created correctly."
        exit 1
    fi
}

# Function to retain only the specified number of backups of each type
retain_backups() {
    local backup_dir="$1"
    local num_backups_to_keep="$2"
    local backups_db=()
    local backups_data=()

    # Using mapfile to read file names into an array
    mapfile -t backups_db < <(ls -t "$backup_dir"/"${SERVICE_NAME}"_db_backup_*.sql 2>/dev/null)
    mapfile -t backups_data < <(ls -t "$backup_dir"/"${SERVICE_NAME}"_moodledata_backup_*.tar.gz 2>/dev/null)

    local num_files_db=${#backups_db[@]}
    local num_files_data=${#backups_data[@]}

    # Remove old database backups if more than the specified number
    if [ "$num_files_db" -gt "$num_backups_to_keep" ]; then
        for ((i=num_backups_to_keep; i<num_files_db; i++)); do
            rm -- "${backups_db[i]}"
            log_message "Removed old database backup: ${backups_db[i]}"
        done
    fi

    # Remove old moodledata backups if more than the specified number
    if [ "$num_files_data" -gt "$num_backups_to_keep" ]; then
        for ((i=num_backups_to_keep; i<num_files_data; i++)); do
            rm -- "${backups_data[i]}"
            log_message "Removed old moodledata backup: ${backups_data[i]}"
        done
    fi
}

# Function to copy backups to BACKUP_STORE and verify the transfer
copy_and_verify_backups() {
    local source_dir="$1"
    local target_dir="$2"
    local num_backups_to_keep="$3"

    mkdir -p "$target_dir"

    # Copy database backups
    for backup_file in "$source_dir/${SERVICE_NAME}_db_backup_"*.sql; do
        if [ -f "$backup_file" ]; then
            cp "$backup_file" "$target_dir"
            verify_backup "$target_dir/$(basename "$backup_file")"
            log_message "Copied database backup: $(basename "$backup_file") to $target_dir"
        fi
    done

    # Copy moodledata backups
    for backup_file in "$source_dir/${SERVICE_NAME}_moodledata_backup_"*.tar.gz; do
        if [ -f "$backup_file" ]; then
            cp "$backup_file" "$target_dir"
            verify_backup "$target_dir/$(basename "$backup_file")"
            log_message "Copied moodledata backup: $(basename "$backup_file") to $target_dir"
        fi
    done

    # Retain only the specified number of backups in the target directory
    retain_backups "$target_dir" "$num_backups_to_keep"
}

# Function to check if BACKUP_STORE is accessible
check_backup_store_accessibility() {
    if [ ! -d "$BACKUP_STORE" ] || [ ! -w "$BACKUP_STORE" ]; then
        log_message "Backup has completed with errors. Backup files created in BACKUP_DIR location."
        log_message "NOTICE: BACKUP_STORE is inaccessible and backup files should be manually transferred."
        log_message "Check BACKUP_STORE accessibility before running this again."
        exit 1
    fi
}

# Check if BACKUP_STORE is accessible
check_backup_store_accessibility

# Create the backup directory if it doesn't exist
if ! mkdir -p "$BACKUP_DIR"; then
    log_message "Error: Failed to create backup directory $BACKUP_DIR."
    exit 1
fi

# Define backup file name and path
DB_BACKUP_FILE="$BACKUP_DIR/${SERVICE_NAME}_db_backup_$(date +\%Y\%m\%d\%H\%M\%S).sql"
DATA_BACKUP_FILE="$BACKUP_DIR/${SERVICE_NAME}_moodledata_backup_$(date +\%Y\%m\%d\%H\%M\%S).tar.gz"

# Perform the database backup using mysqldump
if mysqldump -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" > "$DB_BACKUP_FILE" 2> "$DB_BACKUP_FILE.err"; then
    log_message "Database backup successful: $DB_BACKUP_FILE"
    # Check if .err file is empty and delete it if so
    if [ ! -s "$DB_BACKUP_FILE.err" ]; then
        rm "$DB_BACKUP_FILE.err"
    fi
else
    log_message "Database backup failed"
    if grep -q "Access denied for user" "$DB_BACKUP_FILE.err"; then
        log_message "Error: Access denied for user '$DB_USER' to database '$DB_NAME'."
        log_message "Please ensure the MySQL user has the necessary permissions, especially LOCK TABLES, and try again."
    else
        log_message "Error message from mysqldump:"
        tail -n 1 "$DB_BACKUP_FILE.err" >> "$BACKUP_DIR/${SERVICE_NAME}_backup_log_$(date +\%Y\%m\%d\%H\%M\%S).txt"
    fi
    exit 1
fi

# Perform the moodledata backup using tar and gzip
if tar -czf "$DATA_BACKUP_FILE" -C "$(dirname "$MOODLE_DATA")" "$(basename "$MOODLE_DATA")"; then
    log_message "Moodledata backup successful: $DATA_BACKUP_FILE"
else
    log_message "Moodledata backup failed"
    exit 1
fi

# Verify that the database backup file is non-empty
verify_backup "$DB_BACKUP_FILE"

# Verify that the moodledata backup file is non-empty
verify_backup "$DATA_BACKUP_FILE"

# Copy backups to BACKUP_STORE and verify the transfer
copy_and_verify_backups "$BACKUP_DIR" "$BACKUP_STORE" "$NUM_BACKUPS_TO_KEEP"

# Retain only the specified number of backups in the BACKUP_DIR
retain_backups "$BACKUP_DIR" "$NUM_BACKUPS_TO_KEEP"

log_message "Backup process completed successfully."
