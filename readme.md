# Moodle Backup Script Documentation

This documentation outlines the steps and functions of the `mdl_bu.sh` script, which is designed to back up a Moodle instance by saving both the database and Moodle data directory. Other forms of data backup that should be used in conjunction with this script include:

- **Server Backup**: A periodic full and incremental backup of the entire server.
- **Course Backup**: Moodle performs course backups within its own cron jobs.

## Overview

The script performs the following main tasks:

1. **Load Configuration**: Loads the backup configuration file (`mdl_bu.conf`) and checks the existence of the Moodle `config.php`.
2. **Extract Database and Data Directory Information**: Extracts the database credentials and Moodle data directory from `config.php`.
3. **Setup Backup Directory and Logging**: Checks or creates the backup directory, sets up logging, and generates timestamps for backup filenames.
4. **Backup Operations**: Performs backups of the Moodle database and the Moodle data directory, verifying each operation's success.
5. **Maintenance Mode Management**: Automatically enables maintenance mode before backup and disables it after the backup to ensure data consistency.
6. **Backup Retention**: Copies backups to a specified storage location and manages the retention of older backups.

## Prerequisites

- MySQL or MariaDB database server
- Bash shell environment
- Access to the Moodle `config.php` file
- Necessary permissions for database operations

## Quick Start Guide

### 1. Clone the Repository

Clone the repository containing the `mdl_bu.sh` script to your local environment:

```bash
git clone <repository-url>
```

### 2. Navigate to the Script Directory

Change to the directory containing the script:

```bash
cd <script-directory>
```

### 3. Edit the Configuration File

Create or edit the `mdl_bu.conf` file to configure the script parameters. Refer to the sample configuration below for guidance.

### 4. Create Required Directories

Ensure the following directories exist and have appropriate permissions:

1. **Backup Directory**

   This is where the script will store backup files. Ensure it exists and has the necessary permissions:

   ```bash
   mkdir -p /path/to/backups
   chmod 750 /path/to/backups
   ```

2. **Backup Store Directory**

   This directory is used for storing retained backups. Ensure it exists and has the necessary permissions:

   ```bash
   mkdir -p /path/to/backup/store
   chmod 750 /path/to/backup/store
   ```

   Replace `/path/to/backups` and `/path/to/backup/store` with the actual paths you intend to use.

### 5. Run the Script

Execute the backup script to create a backup of your Moodle instance:

```bash
bash mdl_bu.sh
```

Ensure the script has executable permissions. If not, run:

```bash
chmod +x mdl_bu.sh
```

## Testing the Setup

Before running the script regularly, it is advisable to test the setup:

1. **Check Configuration**: Ensure that `mdl_bu.conf` is correctly configured and points to the right paths.

2. **Verify Permissions**: Check that the script has read access to `config.php` and write access to the backup directories.

3. **Perform a Dry Run**: Execute the script with `echo` statements to simulate the backup process without making any changes. You can modify the script to include `echo` for each significant step to see what actions it would perform.

4. **Review Log Output**: Run the script and examine the log file for any errors or warnings that might need addressing.

## Script Configuration

### `mdl_bu.conf`

The configuration file must be set up with the following parameters:

- `MDL_WEB_DIR`: Path to the web directory for Moodle.
- `MDL_CONFIG_PATH`: Path to the Moodle `config.php` file.
- `BACKUP_DIR`: Directory where the backup files will be stored.
- `BACKUP_STORE`: Directory where backups will be copied to for retention.
- `RETAIN_NUM`: Number of backup sets to retain.

### Sample Configuration File

```conf
MDL_WEB_DIR="/path/to/moodle/web-files"
MDL_CONFIG_PATH="/path/to/moodle/config.php"
BACKUP_DIR="/path/to/backups"
BACKUP_STORE="/path/to/backup/store"
RETAIN_NUM=7
```

## Script Structure and Functions

### 1. Loading Configuration

The script first checks the existence of the configuration file and the Moodle `config.php` file:

```bash
# Load configuration
source /path/to/mdl_bu.conf

# Check if Moodle configuration file exists
if [ ! -f "$MDL_CONFIG_PATH" ]; then
    echo "Moodle configuration file not found: $MDL_CONFIG_PATH"
    exit 1
fi
```

### 2. Extract Database and Data Directory Information

The script extracts database and data directory details using `grep` and `awk`:

```bash
# Extract Moodle database and moodledata directory from config.php
DB_HOST=$(grep "\$CFG->dbhost" "$MDL_CONFIG_PATH" | awk -F"'" '{print $2}')
DB_NAME=$(grep "\$CFG->dbname" "$MDL_CONFIG_PATH" | awk -F"'" '{print $2}')
DB_USER=$(grep "\$CFG->dbuser" "$MDL_CONFIG_PATH" | awk -F"'" '{print $2}')
DB_PASS=$(grep "\$CFG->dbpass" "$MDL_CONFIG_PATH" | awk -F"'" '{print $2}')
MOODLE_DATA=$(grep "\$CFG->dataroot" "$MDL_CONFIG_PATH" | awk -F"'" '{print $2}')
```

### 3. Setup Backup Directory and Logging

The script ensures the backup directory exists and sets up logging for the backup process:

```bash
# Ensure the backup directory exists
if [ ! -d "$BACKUP_DIR" ]; then
    mkdir -p "$BACKUP_DIR"
fi

# Setup log file
LOG_FILE="$BACKUP_DIR/backup_$(date +"%Y%m%d_%H%M%S").log"
exec > >(tee -i "$LOG_FILE")
exec 2>&1

Progress and errors are logged and output to the command line.

log_message() {
    local log_msg="$1"

    # Check if LOG_FILE is writable
    if [ ! -w "$LOG_FILE" ]; then
        # If LOG_FILE is not writable, output message to stderr
        echo "Error: Log file $LOG_FILE is not writable. Outputting message to stderr."
        echo "$(date +'%Y-%m-%d %H:%M:%S') - $log_msg" >&2
        return
    fi

    # Append message to LOG_FILE
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $log_msg" >> "$LOG_FILE"

    # Send log message to command line
    echo "$log_msg"
}

```

### 4. Backup Operations

#### Database Backup

The script uses `mysqldump` to perform a database backup, including error handling for access denied errors:

```bash
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
        tail -n 1 "$DB_BACKUP_FILE.err" >> "$LOG_FILE"
    fi
    exit 1
fi
```

#### Moodle Data Backup

The script backs up the Moodle data directory using `tar` and verifies the backup file:

```bash
# Perform the moodledata backup using tar and gzip
if tar -czf "$DATA_BACKUP_FILE" -C "$(dirname "$MOODLE_DATA")" "$(basename "$MOODLE_DATA")"; then
    log_message "Moodledata backup successful: $DATA_BACKUP_FILE"
else
    log_message "Moodledata backup failed"
    exit 1
fi

# Verify that the moodledata backup file is non-empty
verify_backup "$DATA_BACKUP_FILE"
```

### 5. Maintenance Mode Management

The script includes functions to enable and disable Moodle's maintenance mode during the backup process. The `trap` command ensures that maintenance mode is always disabled when the script exits, even if an error occurs:

```bash
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

# Enable maintenance mode before backups
enable_maintenance_mode
```

### 6. Backup Retention

The script copies backup files to a specified storage directory and retains a certain number of backups:

```bash
# Copy backups to storage location
copy_new_backups "$BACK

UP_STORE"

# Retain the specified number of backups
backup_files=($(ls -t "$BACKUP_STORE"/*))
if [ ${#backup_files[@]} -gt $RETAIN_NUM ]; then
    files_to_delete=("${backup_files[@]:$RETAIN_NUM}")
    for file in "${files_to_delete[@]}"; do
        rm "$file"
    done
fi

log_message "Backup retention completed. Retained $RETAIN_NUM backups."
```

## Troubleshooting Tips

1. **Permission Errors**: Ensure the script has appropriate permissions to access the Moodle configuration file and write to the backup directories.

2. **Database Access Issues**: Verify that the database credentials in `config.php` are correct and that the MySQL user has the necessary permissions, such as `SELECT` and `LOCK TABLES`.

3. **Maintenance Mode**: Check if the script properly enables and disables maintenance mode. Review the log for any errors in these operations.

4. **Log Analysis**: Review the log file after each run to identify any issues or warnings that need attention.

## Automating Backups

To automate backups, you can schedule the script to run periodically using a cron job. Open your crontab file by running:

```bash
crontab -e
```

Add a line to schedule the backup at a desired frequency. For example, to run the backup every day at 2 AM, add:

```bash
0 2 * * * /path/to/mdl_bu.sh
```

## Conclusion

The `mdl_bu.sh` script provides a comprehensive backup solution for Moodle, ensuring both database and data directory backups with error handling and maintenance mode management. Ensure the configuration is set correctly before running the script.

For any issues or further assistance, please refer to the script comments or contact support.
