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
        echo "Error: $var_name is not set. Please check the $CONFIG_FILE file."
        exit 1
    fi
}

# Check if the config.php file exists
if [ ! -f "$MDL_CONFIG_PATH" ]; then
    echo "Error: config.php file not found at $MDL_CONFIG_PATH. Please provide the correct path."
    exit 1
fi

# Check if the config.php file is readable
if [ ! -r "$MDL_CONFIG_PATH" ]; then
    echo "Error: config.php file is not readable. Please check the file permissions."
    exit 1
fi

# Check if the config.php file contains the required configuration variables
required_vars=("\$CFG->dbname" "\$CFG->dbuser" "\$CFG->dbpass" "\$CFG->dbhost" "\$CFG->dataroot")
for var in "${required_vars[@]}"; do
    if ! grep -q "$var" "$MDL_CONFIG_PATH"; then
        echo "Error: $var not found in $MDL_CONFIG_PATH. Please ensure the config.php file is correctly configured."
        exit 1
    fi
done

# Extract database credentials from the config.php file
DB_NAME=$(grep "\$CFG->dbname" "$MDL_CONFIG_PATH" | awk -F"'" '{print $2}')
DB_USER=$(grep "\$CFG->dbuser" "$MDL_CONFIG_PATH" | awk -F"'" '{print $2}')
DB_PASS=$(grep "\$CFG->dbpass" "$MDL_CONFIG_PATH" | awk -F"'" '{print $2}')
DB_HOST=$(grep "\$CFG->dbhost" "$MDL_CONFIG_PATH" | awk -F"'" '{print $2}')

# Extract the moodledata path from the config.php file
MOODLE_DATA=$(grep "\$CFG->dataroot" "$MDL_CONFIG_PATH" | awk -F"'" '{print $2}')

# Check if the variables are set
check_variable "DB_NAME" "$DB_NAME"
check_variable "DB_USER" "$DB_USER"
check_variable "DB_PASS" "$DB_PASS"
check_variable "DB_HOST" "$DB_HOST"
check_variable "MOODLE_DATA" "$MOODLE_DATA"
check_variable "SERVICE_NAME" "$SERVICE_NAME"

# Define backup file name and path
DB_BACKUP_FILE="$BACKUP_DIR/${SERVICE_NAME}_db_backup_$(date +\%Y\%m\%d\%H\%M\%S).sql"
DATA_BACKUP_FILE="$BACKUP_DIR/${SERVICE_NAME}_moodledata_backup_$(date +\%Y\%m\%d\%H\%M\%S).tar.gz"

# Create the backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Check if the backup directory was created successfully
if ! mkdir -p "$BACKUP_DIR"; then
    echo "Error: Failed to create backup directory $BACKUP_DIR."
    exit 1
fi

# Perform the database backup using mysqldump
if mysqldump -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" > "$DB_BACKUP_FILE" 2> "$DB_BACKUP_FILE.err"; then
    echo "Database backup successful: $DB_BACKUP_FILE"
    # Check if .err file is empty and delete it if so
    if [ ! -s "$DB_BACKUP_FILE.err" ]; then
        rm "$DB_BACKUP_FILE.err"
    fi
else
    echo "Database backup failed"
    if grep -q "Access denied for user" "$DB_BACKUP_FILE.err"; then
        echo "Error: Access denied for user '$DB_USER' to database '$DB_NAME'."
        echo "Please ensure the MySQL user has the necessary permissions, especially LOCK TABLES, and try again."
    else
        echo "Error message from mysqldump:"
        tail -n 1 "$DB_BACKUP_FILE.err"
    fi
    exit 1
fi

# Perform the moodledata backup using tar and gzip
if tar -czf "$DATA_BACKUP_FILE" -C "$(dirname "$MOODLE_DATA")" "$(basename "$MOODLE_DATA")"; then
    echo "Moodledata backup successful: $DATA_BACKUP_FILE"
else
    echo "Moodledata backup failed"
    exit 1
fi

# Function to verify that backup files are non-empty
verify_backup() {
    local file="$1"
    if [ ! -s "$file" ]; then
        echo "Error: Backup file $file is empty or not created correctly."
        exit 1
    fi
}

# Verify that the database backup file is non-empty
verify_backup "$DB_BACKUP_FILE"

# Verify that the moodledata backup file is non-empty
verify_backup "$DATA_BACKUP_FILE"

# Function to retain only the last three backups of each type
retain_last_three_backups() {
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
        done
    fi

    # Remove old moodledata backups if more than the specified number
    if [ "$num_files_data" -gt "$num_backups_to_keep" ]; then
        for ((i=num_backups_to_keep; i<num_files_data; i++)); do
            rm -- "${backups_data[i]}"
        done
    fi
}

# Retain only the last three backups of each type
retain_last_three_backups "$BACKUP_DIR" "$NUM_BACKUPS_TO_KEEP"

echo "Backup process completed successfully."
