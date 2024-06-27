# Moodle Backup Script

This script automates the backup of a Moodle instance, including its database and `moodledata` directory. Configuration is managed through separate configuration files.

## Configuration Files

### `mdl_bu.conf.template`
This is the template configuration file. Copy this file to `mdl_bu.conf` and update it with instance-specific values.

### `mdl_bu.conf`
This file contains instance-specific configuration values. It is created by copying `mdl_bu.conf.template` and updating the paths and other settings.

## Main Script File: `mdl_bu.sh`
The main script reads configuration variables from `mdl_bu.conf` and performs the backup operations.

## Backup Storage
Backups are stored in the directory specified in the `mdl_bu.conf` file. Ensure that this directory exists and has the appropriate permissions before running the script.

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

4. **Ensure the backup directory exists and has the correct permissions:**
   ```bash
   mkdir -p /path/to/your/backup
   chmod 755 /path/to/your/backup
   ```

5. **Make the script file executable:**
   ```bash
   chmod +x mdl_bu.sh
   ```

6. **Run the backup script:**
   ```bash
   ./mdl_bu.sh
   ```

7. **Verify the backup process completion message:**
   - Ensure that you see messages indicating the success of database and moodledata backups.
   - Check the backup directory to confirm the presence of the backup files.

## Notes
- The script handles the creation of the backup directory if it does not exist. However, it is recommended to manually ensure the directory exists and has the correct permissions.
- The number of backups to retain is specified in the `mdl_bu.conf` file. Older backups exceeding this number will be deleted automatically.

This process separates configuration from the main script, making it easier to manage instance-specific settings without modifying the script itself.
```

This `README.md` now includes information on making the script executable, details about the backup storage location, and steps to prepare the backup location before running the script.