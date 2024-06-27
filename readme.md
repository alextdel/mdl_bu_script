# Moodle Backup Script

This script automates the backup of a Moodle instance, including its database and `moodledata` directory. Configuration is managed through separate configuration files.

## Configuration Files

### `mdl_bu.conf.template`
This is the template configuration file. Copy this file to `mdl_bu.conf` and update it with instance-specific values.

```bash
# mdl_bu.conf.template

# Path to the Moodle config.php file
MDL_CONFIG_PATH='/path/to/moodle/config.php'

# Path to the backup directory
BACKUP_DIR='/path/to/backup'

# Number of backups to retain
NUM_BACKUPS_TO_KEEP=3
```

### `mdl_bu.conf`
This file contains instance-specific configuration values. It is created by copying `mdl_bu.conf.template` and updating the paths and other settings.

```bash
# mdl_bu.conf

# Path to the Moodle config.php file
MDL_CONFIG_PATH='/path/to/your/moodle/config.php'

# Path to the backup directory
BACKUP_DIR='/path/to/your/backup'

# Number of backups to retain
NUM_BACKUPS_TO_KEEP=3
```

## Main Script File: `mdl_bu.sh`
The main script reads configuration variables from `mdl_bu.conf` and performs the backup operations.

```bash
#!/bin/bash

# Load configuration variables from mdl_bu.conf
CONFIG_FILE='mdl_bu.conf'

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file $CONFIG_FILE not found. Please create it based on mdl_bu.conf.template."
    exit 1
fi

# The 'source' command reads and executes the content of the specified file
# It makes the variables and functions defined in mdl_bu.conf available in this script
source "$CONFIG_FILE"

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
required_vars=('$CFG->dbname' '$CFG->dbuser' '$CFG->dbpass' '$CFG->dbhost' '$CFG->dataroot')
for var in "${required_vars[@]}"; do
    if ! grep -q "$var" "$MDL_CONFIG_PATH"; then
        echo "Error: $var not found in $MDL_CONFIG_PATH. Please ensure the config.php file is correctly configured."
        exit 1
    fi
done

# Extract database credentials from the config.php file
DB_NAME=$(grep '$CFG->dbname' "$MDL_CONFIG_PATH" | awk -F"'" '{print $2}')
DB_USER=$(grep '$CFG->dbuser' "$MDL_CONFIG_PATH" | awk -F"'" '{print $2}')
DB_PASS=$(grep '$CFG->dbpass' "$MDL_CONFIG_PATH" | awk -F"'" '{print $2}')
DB_HOST=$(grep '$CFG->dbhost' "$MDL_CONFIG_PATH" | awk -F"'" '{print $2}')

# Extract the moodledata path from the config.php file
MOODLE_DATA=$(grep '$CFG->dataroot' "$MDL_CONFIG_PATH" | awk -F"'" '{print $2}')

# Check if the variables are set
check_variable "DB_NAME" "$DB_NAME"
check_variable "DB_USER" "$DB_USER"
check_variable "DB_PASS" "$DB_PASS"
check_variable "DB_HOST" "$DB_HOST"
check_variable "MOODLE_DATA" "$MOODLE_DATA"

# Define backup file name and path
DB_BACKUP_FILE="$BACKUP_DIR/moodle_db_backup_$(date +\%Y\%m\%d\%H\%M\%S).sql"
DATA_BACKUP_FILE="$BACKUP_DIR/moodledata_backup_$(date +\%Y\%m\%d\%H\%M\%S).tar.gz"

# Create the backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Check if the backup directory was created successfully
if [ $? -ne 0 ]; then
    echo "Error: Failed to create backup directory $BACKUP_DIR."
    exit 1
fi

# Perform the database backup using mysqldump
mysqldump -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" > "$DB_BACKUP_FILE"

# Check if the database backup was successful
if [ $? -eq 0 ]; then
    echo "Database backup successful: $DB_BACKUP_FILE"
else
    echo "Database backup failed"
    exit 1
fi

# Perform the moodledata backup using tar and gzip
tar -czf "$DATA_BACKUP_FILE" -C "$(dirname "$MOODLE_DATA")" "$(basename "$MOODLE_DATA")"

# Check if the moodledata backup was successful
if [ $? -eq 0 ]; then
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

# Function to retain only the last three backups
retain_last_three_backups() {
    local backup_dir="$1"
    local num_backups_to_keep="$2"
    local num_files
    num_files=$(ls -t "$backup_dir" | grep -E 'moodle_db_backup_|moodledata_backup_' | wc -l)
    if [ "$num_files" -gt "$num_backups_to_keep" ]; then
        ls -t "$backup_dir" | grep -E 'moodle_db_backup_|moodledata_backup_' | tail -n +$(($num_backups_to_keep + 1)) | xargs -I {} rm -- "$backup_dir"/{}
    fi
}

# Retain only the last three backups
retain_last_three_backups "$BACKUP_DIR" "$NUM_BACKUPS_TO_KEEP"

echo "Backup process completed successfully."
```

## Quickstart

Follow these steps to use the backup script:

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd <repository-directory>
   ```

2. **Copy the template configuration file:**
   ```bash
   cp mdl_bu.conf.template mdl_bu.conf
   ```

3. **Edit `mdl_bu.conf` with your instance-specific values:**
   ```bash
   nano mdl_bu.conf
   # Update the paths and settings as needed
   ```

4. **Run the backup script:**
   ```bash
   ./mdl_bu.sh
   ```

5. **Verify the backup process completion message:**
   - Ensure that you see messages indicating the success of database and moodledata backups.
   - Check the backup directory to confirm the presence of the backup files.

This process separates configuration from the main script, making it easier to manage instance-specific settings without modifying the script itself.
```

This `README.md` provides a clear guide on how to set up and use the backup script, including a quickstart section with step-by-step instructions.