#!/bin/bash

# Set up logging functionality
# Global log file path with a timestamp
LOG_FILE="$BACKUP_DIR/${SERVICE_NAME}_backup_log_$(date +'%Y%m%d%H%M%S').txt"

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

# Attempt to create the log file
if ! touch "$LOG_FILE"; then
    log_message "Error: Unable to create log file at $LOG_FILE"
    exit 1
fi

# Redirect stdout and stderr to the log file
exec > >(tee -i "$LOG_FILE")
exec 2>&1

# Function to check if a variable is set and valid
check_variable() {
    local var_name="$1"
    local var_value="$2"
    local var_type="$3"
    local valid_value="$4"
    
    # Check if the variable is empty
    if [ -z "$var_value" ]; then
        log_message "Error: $var_name is not set in $CONFIG_FILE. Please set it and try again."
        exit 1
    fi

    # Validate the variable based on its expected type
    case "$var_type" in
        "integer")
            # Ensure the variable is an integer
            if ! [[ "$var_value" =~ ^[0-9]+$ ]]; then
                log_message "Error: $var_name must be an integer. Current value: $var_value"
                exit 1
            fi
            ;;
        "directory")
            # Ensure the variable is a valid directory path
            if [ ! -d "$var_value" ]; then
                log_message "Error: $var_name is not a valid directory. Current value: $var_value"
                exit 1
            fi
            ;;
        "file")
            # Ensure the variable is a valid file path
            if [ ! -f "$var_value" ]; then
                log_message "Error: $var_name is not a valid file. Current value: $var_value"
                exit 1
            fi
            ;;
        "text")
            # Ensure the variable is not equal to a specific invalid value
            if [ "$var_value" == "$valid_value" ]; then
                log_message "Error: $var_name must not be '$valid_value'. Current value: $var_value"
                exit 1
            fi
            ;;
        *)
            log_message "Error: Unknown type $var_type for $var_name."
            exit 1
            ;;
    esac
}

# Function to verify that a backup file is non-empty
verify_backup() {
    local file="$1"
    if [ ! -s "$file" ]; then
        log_message "Error: Backup file $file is empty or not created correctly."
        exit 1
    else
        log_message "Backup file $file is verified as created correctly."
    fi
}

# Function to combine database and Moodledata backups into a single tar.gz file
combine_backups() {
    local combined_file="$1"
    log_message "Combining database and Moodledata backups into: $combined_file"
    tar -czf "$combined_file" -C "$BACKUP_DIR" "$(basename "$DB_BACKUP_FILE")" "$(basename "$DATA_BACKUP_FILE")"
    log_message "Combined backups into: $combined_file"
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

# Function to clean up old log files (>7 days) with error trapping
log_cleanup() {
    log_message "Starting log cleanup. Retaining logs based on the defined criteria."

    # Attempt to find and remove old log files, trapping errors
    if ! find "$BACKUP_DIR" -name "${SERVICE_NAME}_backup_log_*.txt" -mtime +7 -exec rm {} \;; then
        log_message "Error: Log cleanup failed. Unable to remove old log files."
    else
        log_message "Log cleanup completed successfully."
    fi
}

# Load configuration variables from mdl_bu.conf
# dirname ensures working dir is correct to ensure .conf is found
CONFIG_FILE="$(dirname "$0")/mdl_bu.conf"

# Initialise a flag to tracke the maintenance mode state
MAINTENANCE_ENABLED=false

# Check if configuration file exists
if [ ! -f "$CONFIG_FILE" ]; then
    log_message "Error: Configuration file $CONFIG_FILE not found. Please create it based on mdl_bu.conf.template."
    exit 1
fi

# Load the configuration file to set environment variables
# shellcheck disable=SC1090
source "$CONFIG_FILE"

# Check if required variables are set and valid
check_variable "NUM_BACKUPS_TO_KEEP" "$NUM_BACKUPS_TO_KEEP" "integer"
check_variable "BACKUP_DIR" "$BACKUP_DIR" "directory"
check_variable "BACKUP_STORE" "$BACKUP_STORE" "directory"
check_variable "MDL_CONFIG_PATH" "$MDL_CONFIG_PATH" "file"
check_variable "MDL_WEB_DIR" "$MDL_WEB_DIR" "directory"
check_variable "SERVICE_NAME" "$SERVICE_NAME" "text" "your_service_name"

# Extract database credentials and Moodle data directory from Moodle's config.php
DB_HOST=$(grep "\$CFG->dbhost" "$MDL_CONFIG_PATH" | awk -F"'" '{print $2}')
DB_NAME=$(grep "\$CFG->dbname" "$MDL_CONFIG_PATH" | awk -F"'" '{print $2}')
DB_USER=$(grep "\$CFG->dbuser" "$MDL_CONFIG_PATH" | awk -F"'" '{print $2}')
DB_PASS=$(grep "\$CFG->dbpass" "$MDL_CONFIG_PATH" | awk -F"'" '{print $2}')
MOODLE_DATA=$(grep "\$CFG->dataroot" "$MDL_CONFIG_PATH" | awk -F"'" '{print $2}')

# Define the path to the maintenance CLI script using the web root directory
MAINTENANCE_SCRIPT="${MDL_WEB_DIR}/admin/cli/maintenance.php"

# Function to enable maintenance mode
enable_maintenance_mode() {
    if php "$MAINTENANCE_SCRIPT" --enable; then
        MAINTENANCE_ENABLED=true
        log_message "Enabling maintenance mode..."
        
    else
        log_message "Error: failed to enable maintenance mode."
        exit 1
    fi
}

# Function to disable maintenance mode only if it was enabled
disable_maintenance_mode() {
    if [ "$MAINTENANCE_ENABLED" = true ]; then
        log_message "Disabling maintenance mode..."
        if php "$MAINTENANCE_SCRIPT" --disable; then
            MAINTENANCE_ENABLED=false
        else
            log_message "Error: Failed to disable maintenance mode."
            log_message "You may need to run this manually: php $MAINTENANCE_SCRIPT --disable"
            exit 1
        fi
    else
        log_message "Maintenance mode is already disabled, skipping."
    fi
}

# Trap any exit signal and call disable_maintenance_mode to ensure maintenance mode is disabled
trap 'if [ "$MAINTENANCE_ENABLED" = true ]; then disable_maintenance_mode; fi' EXIT

# Enable maintenance mode at the start of the backup
enable_maintenance_mode

# Check if BACKUP_STORE is accessible before proceeding
check_backup_store_accessibility

# Create the backup directory if it doesn't exist
if ! mkdir -p "$BACKUP_DIR"; then
    log_message "Error: Failed to create backup directory $BACKUP_DIR."
    exit 1
fi

# Define backup file names and paths
DB_BACKUP_FILE="$BACKUP_DIR/${SERVICE_NAME}_db_backup_$(date +%Y%m%d%H%M%S).sql"
DATA_BACKUP_FILE="$BACKUP_DIR/${SERVICE_NAME}_moodledata_backup_$(date +%Y%m%d%H%M%S).tar.gz"
COMBINED_BACKUP_FILE="$BACKUP_DIR/${SERVICE_NAME}_backup_$(date +%Y%m%d%H%M%S).tar.gz"

# Perform the database backup using mysqldump
log_message "Starting database backup..."
if mysqldump -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" > "$DB_BACKUP_FILE" 2> "$DB_BACKUP_FILE.err"; then
    log_message "Database backup successful: $DB_BACKUP_FILE"
    # Remove error file if empty
    if [ ! -s "$DB_BACKUP_FILE.err" ]; then
        rm "$DB_BACKUP_FILE.err"
    fi
else
    log_message "Database backup failed"
    # Handle access denied error separately
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
log_message "Starting Moodledata backup..."
if tar -czf "$DATA_BACKUP_FILE" -C "$(dirname "$MOODLE_DATA")" "$(basename "$MOODLE_DATA")"; then
    log_message "Moodledata backup successful: $DATA_BACKUP_FILE"
else
    log_message "Moodledata backup failed"
    exit 1
fi

# Disable maintenance mode after moodledata and database access backup completed
log_message "Disabling maintenance mode"
disable_maintenance_mode

# Combine backups into a single tar.gz file
combine_backups "$COMBINED_BACKUP_FILE"

# Verify the combined backup file
verify_backup "$COMBINED_BACKUP_FILE"

# Transfer combined backup to the backup store
log_message "Transferring combined backup file to backup store..."
if cp "$COMBINED_BACKUP_FILE" "$BACKUP_STORE"; then
    log_message "Transfer successful: $COMBINED_BACKUP_FILE to $BACKUP_STORE"
    # Remove the local backup files if transfer was successful
    log_message "Removing local backup files:\n$DB_BACKUP_FILE\n$DATA_BACKUP_FILE\n$COMBINED_BACKUP_FILE"
    rm "$DB_BACKUP_FILE" "$DATA_BACKUP_FILE" "$COMBINED_BACKUP_FILE"
    log_message "Local backup files removed after successful transfer."
else
    log_message "Transfer failed: $COMBINED_BACKUP_FILE to $BACKUP_STORE"
    log_message "Local backup files retained for manual transfer."
    exit 1
fi

# Call the log cleanup function
log_cleanup

# End of script
log_message "Backup script completed successfully."
