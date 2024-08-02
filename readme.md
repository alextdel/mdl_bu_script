Here's a revised version of your README file with a contents list, improved formatting, and logical structure:

---

# Moodle Backup Script

This script automates the backup of a Moodle instance, including its database and `moodledata` directory. Configuration is managed through separate configuration files.

When the script is run successfully, the output will show the following backup files, including the associated log file, created with timestamps:

```
-rw-r--r-- 1 user user 4231656 Jun 28 09:27 your_service_name_moodledata_backup_YYYYMMDDHHMMSS.tar.gz
-rw-r--r-- 1 user user 1669354 Jun 28 09:27 your_service_name_db_backup_YYYYMMDDHHMMSS.sql
-rw-r--r-- 1 user user 1669354 Jun 28 09:27 your_service_name_backup_log_YYYYMMDDHHMMSS.txt
```

Note: The log file will contain the same information as the CLI output if this script is run manually.

## Contents

1. [Running the Script](#running-the-script)
2. [Configuration Files](#configuration-files)
3. [Main Script File: `mdl_bu.sh`](#main-script-file-mdl_bush)
4. [Backup Files](#backup-files)
5. [Quickstart](#quickstart)
6. [Notes](#notes)
7. [Detailed Script Description: Backup Script Process Flow](#detailed-script-description-backup-script-process-flow)

## Running the Script

### 1. From the Terminal:

```sh
cd /path/to/the/directory_containing_script
./mdl_bu.sh
```

Note: Depending on user permissions, **sudo** may be required.

### 2. From a Cron Job:

This script can be run automatically using the Linux cron system. The following shows how to set up a daily backup at 2:30 AM.

#### a. Open the crontab file for editing:

```sh
crontab -e
```

#### b. Add a new cron job entry:

Add the following line to schedule the `mdl_bu.sh` script to run daily at 2:30 AM. Make sure to replace `/path/to/mdl_bu.sh` with the actual path to your script.

```sh
30 2 * * * /path/to/mdl_bu.sh >> /path/to/web-dir-parent/mdl_backup/mdl_bu_files/backup_cron_log.txt 2>&1
```

This line breaks down as follows:
- `30 2 * * *` specifies the schedule (2:30 AM every day).
- `/path/to/mdl_bu.sh` is the path to your backup script.
- `>> /path/to/web-dir-parent/mdl_backup/mdl_bu_files/backup_cron_log.txt 2>&1` appends both the standard output and standard error of the script to `backup_cron_log.txt`.

#### c. Save and exit the crontab editor:

- If you're using `nano` as the editor, press `Ctrl+X`, then `Y` to confirm, and `Enter` to save the changes.

#### d. Verify the cron job:

To check if your cron job is set up correctly, you can list the current cron jobs with:

```sh
crontab -l
```

This setup ensures that your Moodle backup script runs daily at 2:30 AM and logs the output and errors to `backup_cron_log.txt` for review.

## Configuration Files

### `mdl_bu.conf.template`

This is the template configuration file. Copy this file to `mdl_bu.conf` and update it with instance-specific values.

### `mdl_bu.conf`

This file contains instance-specific configuration values. It is created by copying `mdl_bu.conf.template` and updating the paths and other settings. This file is not part of the Git repo.

## Main Script File: `mdl_bu.sh`

The main script reads configuration variables from `mdl_bu.conf` and performs the backup operations.

## Backup Files

Backup files are:
- **First**, generated into the `BACKUP_DIR` location defined in the `mdl_bu.conf` file - this is the local copy of the backup files.
- **Second**, copied to the `BACKUP_STORE` location defined in the `mdl_bu.conf` file - this is the remote backup version stored in Azure Blob Storage.

### 1. Backup Directory (`BACKUP_DIR`)

- Do not place the backup directory inside the web folder (public_html or equivalent).
- Create a directory (and set it in the `mdl_bu.conf` file as `BACKUP_DIR`) in the same domain folder as the website directory. Often this will be the same place as the `moodledata` folder, e.g.:

```
domain_dir
|-- moodledata
|-- mdl_backup
|-- public_html
```

### 2. Backup Storage (`BACKUP_STORE`)

This should be set up by the server admin. It is a directory on the server (e.g., /blob/mnt) that points to a storage target in the Azure environment (i.e., a cloud backup location). For this backup script, the location is defined in the `mdl_bu.conf` file as `BACKUP_STORE`. Ensure that this directory exists and has the appropriate permissions before running the script.

### 3. Retention of Backup Files

The number of backup files of each type (`.tar.gz`, `.sql`, `.txt`) that are to be retained is defined as `NUM_BACKUPS_TO_KEEP` in the `mdl_bu.conf`.

## Quickstart

Follow these steps to use the backup script:

### 1. Create the `mdl_backup` and `mdl_bu_files` directories:

The script will attempt to create the backup files directory, but it is better to set this up first:

```sh
mkdir -p /path/to/web-dir-parent/mdl_backup/mdl_bu_files
cd /path/to/web-dir-parent/mdl_backup
```

### 2. Clone the repository:

While in `/path/to/web-dir-parent/mdl_backup`:

```sh
git clone <repository-url>  # a sub-directory for the git repo is made e.g., 'mdl_bu_script'
cd <repository-directory>
```

### 3. Copy the template configuration file:

```sh
cp mdl_bu.conf.template mdl_bu.conf
```

### 4. Edit `mdl_bu.conf` with your instance-specific values:

```sh
nano mdl_bu.conf
# Update the paths and settings as needed
```

### 5. Ensure the backup directory exists and has the correct permissions:

```sh
mkdir -p /path/to/web-dir-parent/mdl_backup/mdl_bu_files
chmod 755 /path/to/web-dir-parent/mdl_backup/mdl_bu_files
```

### 6. Make the script file executable:

```sh
chmod +x mdl_bu.sh
```

### 7. Ensure the MariaDB/MySQL DB permissions are correct:

```sh
mysql -u root -p
Enter password: 
```

```sql
MariaDB [(none)]> grant lock tables on db_name.* to 'db_user'@'localhost';
MariaDB [(none)]> flush privileges;
MariaDB [(none)]> show grants for db_user@localhost;
+----------------------------------------------------------------------------------------------+
| Grants for db_user@localhost                                                                  |
+----------------------------------------------------------------------------------------------+
| GRANT USAGE ON *.* TO `db_user`@`localhost` IDENTIFIED BY PASSWORD 'password-hash-shown'     |
| GRANT ALL PRIVILEGES ON `db_name`.* TO `db_user`@`localhost` WITH GRANT OPTION               |
| GRANT ALL PRIVILEGES ON `other_database_name`.* TO `db_user`@`localhost` WITH GRANT OPTION   |
| GRANT LOCK TABLES ON `db_name`.* TO `db_user`@`localhost`                                    |
+----------------------------------------------------------------------------------------------+
4 rows in set (0.000 sec)
MariaDB [(none)]> exit
```

### 8. Run the backup script:

```sh
./mdl_bu.sh
```

### 9. Verify the backup process completion message:

- Ensure that you see messages indicating the success of database and moodledata backups.
- Check the backup directory to confirm the presence of the backup files.

## Notes

- The script handles the creation of the backup directory if it does not exist. However, it is recommended to manually ensure the directory exists and has the correct permissions.
- The number of backups to retain is specified in the `mdl_bu.conf` file. Older backups exceeding this number will be deleted automatically.

---

## Detailed Script Description: Backup Script Process Flow

This script automates the backup process for Moodle, ensuring that both database and Moodle data are securely backed up and managed efficiently. The process flow is outlined below:

### 1. Configuration File Loading

- The script starts by loading configuration variables from `mdl_bu.conf`.
- It checks if the configuration file exists and exits with an error message if not found.

```bash
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
```

### 2. Database and Moodle Data Extraction

- The script reads the `config.php` file to extract database credentials and the Moodle data directory path.
-

 It checks for the existence of the `config.php` file and exits with an error message if not found.

```bash
# Ensure the Moodle config.php file exists and is readable
if [ ! -f "$CONFIG_PHP" ]; then
    echo "Error: config.php not found at $CONFIG_PHP. Please check the path and try again."
    exit 1
fi

# Extract Moodle database and moodledata directory from config.php
DB_NAME=$(awk -F"'" '/dbname/{print $4}' "$CONFIG_PHP")
DB_USER=$(awk -F"'" '/dbuser/{print $4}' "$CONFIG_PHP")
DB_PASS=$(awk -F"'" '/dbpass/{print $4}' "$CONFIG_PHP")
DB_HOST=$(awk -F"'" '/dbhost/{print $4}' "$CONFIG_PHP")
MOODLE_DATA_DIR=$(awk -F"'" '/dataroot/{print $4}' "$CONFIG_PHP")
```

### 3. Backup Directory Setup

- The script ensures that the backup directory exists and is writable.
- If the backup directory does not exist, it attempts to create it.

```bash
# Ensure the backup directory exists and is writable
if [ ! -d "$BACKUP_DIR" ]; then
    echo "Backup directory not found. Attempting to create $BACKUP_DIR..."
    mkdir -p "$BACKUP_DIR"
fi

if [ ! -w "$BACKUP_DIR" ]; then
    echo "Error: Backup directory $BACKUP_DIR is not writable. Please check permissions."
    exit 1
fi

# Ensure the backup storage location exists and is writable
if [ ! -d "$BACKUP_STORE" ]; then
    echo "Error: Backup storage location $BACKUP_STORE not found."
    exit 1
fi

if [ ! -w "$BACKUP_STORE" ]; then
    echo "Error: Backup storage location $BACKUP_STORE is not writable. Please check permissions."
    exit 1
fi
```

### 4. Timestamp and Filenames

- The script generates a timestamp to uniquely identify the backup files.
- Filenames for the database and Moodle data backups are constructed using the timestamp and service name.

```bash
# Generate a timestamp for the backup filenames
TIMESTAMP=$(date +"%Y%m%d%H%M%S")

# Construct filenames for database and moodledata backups
DB_BACKUP_FILE="${SERVICE_NAME}_db_backup_${TIMESTAMP}.sql"
DATA_BACKUP_FILE="${SERVICE_NAME}_moodledata_backup_${TIMESTAMP}.tar.gz"
LOG_FILE="${SERVICE_NAME}_backup_log_${TIMESTAMP}.txt"
```

### 5. Logging Setup

- A log file is created in the backup directory to record the script's output and errors.
- The script uses redirection to capture both standard output and error messages.

```bash
# Create a log file in the backup directory
exec > >(tee -a "${BACKUP_DIR}/${LOG_FILE}") 2>&1

echo "Starting Moodle backup process..."
echo "Service: $SERVICE_NAME"
echo "Date: $(date)"
echo "Backup Directory: $BACKUP_DIR"
echo "Backup Storage: $BACKUP_STORE"
echo "Backup Timestamp: $TIMESTAMP"
```

### 6. Database Backup

- The script uses `mysqldump` to create a backup of the Moodle database.
- It checks the exit status of the command to verify success or failure.

```bash
# Backup the Moodle database using mysqldump
echo "Backing up Moodle database to $BACKUP_DIR/$DB_BACKUP_FILE..."
mysqldump -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" > "${BACKUP_DIR}/${DB_BACKUP_FILE}"

if [ $? -eq 0 ]; then
    echo "Database backup completed successfully."
else
    echo "Error: Database backup failed."
    exit 1
fi
```

### 7. Moodle Data Backup

- The script creates a tarball of the Moodle data directory using `tar`.
- It checks the exit status of the command to verify success or failure.

```bash
# Backup the moodledata directory using tar
echo "Backing up Moodle data directory to $BACKUP_DIR/$DATA_BACKUP_FILE..."
tar -czf "${BACKUP_DIR}/${DATA_BACKUP_FILE}" -C "$MOODLE_DATA_DIR" .

if [ $? -eq 0 ]; then
    echo "Moodle data backup completed successfully."
else
    echo "Error: Moodle data backup failed."
    exit 1
fi
```

### 8. Backup Storage

- The script copies the backup files to the backup storage directory.
- It checks the exit status of the command to verify success or failure.

```bash
# Copy backup files to the backup storage directory
echo "Copying backup files to $BACKUP_STORE..."
cp "${BACKUP_DIR}/${DB_BACKUP_FILE}" "${BACKUP_STORE}/"
cp "${BACKUP_DIR}/${DATA_BACKUP_FILE}" "${BACKUP_STORE}/"

if [ $? -eq 0 ]; then
    echo "Backup files copied to $BACKUP_STORE successfully."
else
    echo "Error: Failed to copy backup files to $BACKUP_STORE."
    exit 1
fi
```

### 9. Old Backups Deletion

- The script deletes old backup files exceeding the specified retention number.
- It lists and removes old backups based on timestamps.

```bash
# Delete old backup files exceeding the specified retention number
echo "Deleting old backups in $BACKUP_DIR..."

NUM_BACKUPS_TO_KEEP=7  # Number of backup sets to retain
BACKUP_FILES=$(ls -1t "${BACKUP_DIR}/${SERVICE_NAME}_"* | grep -v "${LOG_FILE}")

for file in $BACKUP_FILES; do
    if [ $NUM_BACKUPS_TO_KEEP -gt 0 ]; then
        echo "Keeping: $file"
        ((NUM_BACKUPS_TO_KEEP--))
    else
        echo "Deleting: $file"
        rm -f "$file"
    fi
done

echo "Backup process completed successfully."
echo "Log file: ${BACKUP_DIR}/${LOG_FILE}"
```

## Conclusion

The Moodle backup script provides a comprehensive and automated solution for backing up Moodle instances. By following the outlined process, you can ensure the integrity and security of your Moodle data.

---

This README provides a comprehensive guide for setting up, configuring, and running the Moodle backup script. Feel free to let me know if you have any more suggestions or need further assistance!