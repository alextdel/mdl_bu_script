#!/bin/bash

# Load configuration variables from mdl_bu.conf
CONFIG_FILE='mdl_bu.conf'

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file $CONFIG_FILE not found. Please create it based on mdl_bu.conf.template."
    exit 1
fi

# The 'source' command reads and executes the content of the specified file
source "$CONFIG_FILE"

# Function to check if a variable is set and valid
check_variable() {
    local var_name="$1"
    local var_value="$2"
    local var_type="$3"
    local valid_value="$4"
    
    if [ -z "$var_value" ]; then
        echo "Error: $var_name is not set in $CONFIG_FILE. Please set it and try again."
        exit 1
    fi

    case "$var_type" in
        "integer")
            if ! [[ "$var_value" =~ ^[0-9]+$ ]]; then
                echo "Error: $var_name must be an integer. Current value: $var_value"
                exit 1
            fi
            ;;
        "directory")
            if [ ! -d "$var_value" ]; then
                echo "Error: $var_name is not a valid directory. Current value: $var_value"
                exit 1
            fi
            ;;
        "file")
            if [ ! -f "$var_value" ]; then
                echo "Error: $var_name is not a valid file. Current value: $var_value"
                exit 1
            fi
            ;;
        "text")
            if [ "$var_value" == "$valid_value" ]; then
                echo "Error: $var_name must not be '$valid_value'. Current value: $var_value"
                exit 1
            fi
            ;;
        *)
            echo "Error: Unknown type $var_type for $var_name."
            exit 1
            ;;
    esac
}

# Check if required variables are set and valid
check_variable "NUM_BACKUPS_TO_KEEP" "$NUM_BACKUPS_TO_KEEP" "integer"
check_variable "BACKUP_DIR" "$BACKUP_DIR" "directory"
check_variable "BACKUP_STORE" "$BACKUP_STORE" "directory"
check_variable "MDL_CONFIG_PATH" "$MDL_CONFIG_PATH" "file"
check_variable "MDL_WEB_DIR" "$MDL_WEB_DIR" "directory"
check_variable "SERVICE_NAME" "$SERVICE_NAME" "text" "your_service_name"

# Read Moodle config.php file and extract database credentials and Moodle data directory
if [ ! -f "$MDL_CONFIG_PATH" ]; then
    echo "Error: Moodle configuration file $MDL_CONFIG_PATH not found."
    exit 1
fi

DB_HOST=$(grep "\$CFG->dbhost" "$MDL_CONFIG_PATH" | awk -F"'" '{print $2}')
DB_NAME=$(grep "\$CFG->dbname" "$MDL_CONFIG_PATH" | awk -F"'" '{print $2}')
DB_USER=$(grep "\$CFG->dbuser" "$MDL_CONFIG_PATH" | awk -F"'" '{print $2}')
DB_PASS=$(grep "\$CFG->dbpass" "$MDL_CONFIG_PATH" | awk -F"'" '{print $2}')
MOODLE_DATA=$(grep "\$CFG->dataroot" "$MDL_CONFIG_PATH" | awk -F"'" '{print $2}')

# Define the path to the maintenance CLI script using the web root directory
MAINTENANCE_SCRIPT="${MDL_WEB_DIR}/admin/cli/maintenance.php"

# Function to enable maintenance mode
enable_maintenance_mode() {
    echo "Enabling maintenance mode..."
    if ! php "$MAINTENANCE_SCRIPT" --enable; then
        log_message "Error: failed to enable maintenance mode."
        exit 1
    fi
}

# Function to disable maintenance mode
disable_maintenance_mode() {
    echo "Disabling maintenance mode..."
    if ! php "$MAINTENANCE_SCRIPT" --disable; then
        echo "Error: Failed to disable maintenance mode."
        log_message "Error: failed to disable maintenance mode\n- you may need to run this manually from the command line ie. php $MDL_WEB_DIR/admin/cli/maintenance.php --disable"
        exit 1
    fi
}

# Function to handle script exit
cleanup() {
    disable_maintenance_mode
}

# Trap any exit signal and call cleanup
trap cleanup EXIT

# Enable maintenance mode
enable_maintenance_mode

# Global log file
LOG_FILE="$BACKUP_DIR/${SERVICE_NAME}_backup_log_$(date +'%Y%m%d%H%M%S').txt"

# Attempt to create the log file
if ! touch "$LOG_FILE"; then
    echo "Error: Unable to create log file at $LOG_FILE"
    exit 1
fi

# Redirect stdout and stderr to the log file
exec > >(tee -i "$LOG_FILE")
exec 2>&1

# Function to log messages to a specified log file
log_message() {
    local log_msg="$1"
    
    # Check if LOG_FILE is writable
    if [ ! -w "$LOG_FILE" ]; then
        echo "Error: Log file $LOG_FILE is not writable. Outputting message to stderr."
        echo "$(date +'%Y-%m-%d %H:%M:%S') - $log_msg" >&2
        return
    fi

    echo "$(date +'%Y-%m-%d %H:%M:%S') - $log_msg" >> "$LOG_FILE"
    echo "$log_msg"
}

# Function to verify that backup files are non-empty
verify_backup() {
    local file="$1"
    if [ ! -s "$file" ]; then
        log_message "Error: Backup file $file is empty or not created correctly."
        exit 1
    else
        log_message "Backup file $file is verified as created correctly."
    fi
}

# Function to copy newly created backups to BACKUP_STORE without overwriting existing files
copy_new_backups() {
    local source_dir="$1"
    local target_dir="$2"

    mkdir -p "$target_dir"

    copy_file_if_new() {
        local file="$1"
        local target="$2"

        if [ ! -f "$target" ]; then
            cp "$file" "$target_dir"
            verify_backup "$target_dir/$(basename "$file")"
            log_message "Copied backup: $(basename "$file") to $target_dir"
        fi
    }

    # Copy database backups
    for backup_file in "$source_dir/${SERVICE_NAME}_db_backup_"*.sql; do
        if [ -f "$backup_file" ]; then
            copy_file_if_new "$backup_file" "$target_dir/$(basename "$backup_file")"
        fi
    done

    # Copy moodledata backups
    for backup_file in "$source_dir/${SERVICE_NAME}_moodledata_backup_"*.tar.gz; do
        if [ -f "$backup_file" ]; then
            copy_file_if_new "$backup_file" "$target_dir/$(basename "$backup_file")"
        fi
    done
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
DB_BACKUP_FILE="$BACKUP_DIR/${SERVICE_NAME}_db_backup_$(date +%Y%m%d%H%M%S).sql"
DATA_BACKUP_FILE="$BACKUP_DIR/${SERVICE_NAME}_moodledata_backup_$(date +%Y%m%d%H%M%S).tar.gz"

# Perform the database backup using mysqldump
if mysqldump -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" > "$DB_BACKUP_FILE" 2> "$DB_BACKUP_FILE.err"; then
    log_message "Database backup successful: $DB_BACKUP_FILE"
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
        tail -n 1 "$DB_BACKUP_FILE.err" >> "$LOG_FILE"
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

# Copy newly created backups to BACKUP_STORE and verify the transfer
copy_new_backups "$BACKUP_DIR" "$BACKUP_STORE"

# Rotate old backups in the BACKUP_STORE, keeping only the latest $NUM_BACKUPS_TO_KEEP backups
rotate_old_backups() {
    local backup_dir="$1"
    local num_to_keep="$2"

    # Find and delete old backups, keeping only the latest $NUM_BACKUPS_TO_KEEP backups
    for backup_type in db_backup moodledata_backup; do
        # Find and list backup files, sorting by modification time and excluding the most recent ones
        local backups
        backups=$(find "$backup_dir" -maxdepth 1 -name "${SERVICE_NAME}_${backup_type}_*" -print0 | xargs -0 ls -1t | tail -n +$((num_to_keep + 1)))

        if [ -n "$backups" ]; then
            # Remove old backups
            echo "$backups" | xargs rm -f
            log_message "Old backups removed for $backup_type. Retained $num_to_keep backups."
        fi
    done
}

# Rotate old backups in the BACKUP_STORE
rotate_old_backups "$BACKUP_STORE" "$NUM_BACKUPS_TO_KEEP"

# Clear local backup directory after successful transfer
if rm -rf "${BACKUP_DIR:?}/*"; then
    log_message "Local backup directory cleared."
else
    log_message "Error: Failed to clear local backup directory."
    exit 1
fi

log_message "Backup process completed successfully."
