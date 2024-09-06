# Moodle Backup Script Documentation

This documentation outlines the steps and functions of the `mdl_bu.sh` script, which is designed to back up a Moodle instance by saving both the database and Moodle data directory.
This script can be run manually from the terminal command line but will usually be tested and then run as a daily cron job.

Other forms of data backup that should be used in conjunction with this script include:

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
7. **Backup file and log file rotation**: to manage storage the config file determines the number of backup files that will be retained.
8. **Detailed logging functions**: to assist with administration and fault finding a detailed logging system is built in. When run from the command line, all logging messages can be viewed in the terminal.

## Prerequisites

- MySQL or MariaDB database server
- Bash shell environment
- Access to the Moodle `config.php` file
- Necessary permissions for database operations

## Quick Start Guide

*Note:* This backup script and associated files usually reside in the same parent directory as the web-filed directory 
 ```
 ___public_html
  |_mdl_backup
         |_mdl_bu_files
         |_mdl_bu_script
               |_mdl_bu.conf
               |_mdl_bu.sh
               |_mdl_bu.conf.template
               |_readme.md
 ```
   

### 1. Create/Navigate to the Script Directory

Change to the directory containing the script (eg. path/mdl_bu_script/):

```bash
cd <script-directory>
```

### 2. Clone the Repository (https://github.com/alextdel/mdl_bu_script.git or use the SSH location)

Clone the repository containing the `mdl_bu.sh` script to your local environment:

```bash
git clone <repository-url>
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
   ***NOTE*** - this may be a separate data store such as an AZURE blob store or AWS S3 container - set permissions accordingly.

   ```bash
   mkdir -p /path/to/backup/store
   chmod 750 /path/to/backup/store (if a linux-type file store)
   ```

   Replace `/path/to/backups` and `/path/to/backup/store` with the actual paths you intend to use.

---
***A NOTE ON UPDATING***
This file along with the config template and script file are from the repo at:
 - https://github.com/alextdel/mdl_bu_script.git or use the SSH location
 
 To update to the latest repo version:
 
 1. `cd /home/user/path/to/mdl_bu_script`
 2. `git stash`
 3. `git pull`
 4. `git stash drop` this gets rid of the old version of files but also means we need to reset the script to be executable ...
 5. `chmod +x mdl_bu.sh`
 
 Script is now ready to run 
 
 6. /mdl_bu.sh - or see below

 Once tested the cron job method of running this script automatically can be used.
 --- 


### 5. Run the Script

Ensure the script has executable permissions. If not, run:

```bash
chmod +x mdl_bu.sh
```

Execute the backup script to create a backup of your Moodle instance:

```bash
bash mdl_bu.sh
```

## Testing the Setup

Before running the script regularly, it is advisable to test the setup:

1. **Check Configuration**: Ensure that `mdl_bu.conf` is correctly configured and points to the right paths.

2. **Verify Permissions**: Check that the script has read access to `config.php` and write access to the backup directories.

3. **Perform a Test Run**: Preferably on a staging server or after you have done a manual backup prior to testing.

4. **Review Log Output**: Run the script and examine the log file for any errors or warnings that might need addressing.

5. **Check File Handling**: Check the backup files have been stored in the BACKUP_STORE directory and that the BACKUP_DIR location has been cleared of intermediate backup files **except the latest log files**.

## Script Configuration

### `mdl_bu.conf`

The configuration file must be set up with the following parameters:

 - MDL_WEB_DIR='/path/to/moodle/web_files' - #Path to Moodle web directory

 - MDL_CONFIG_PATH='/path/to/moodle/config.php' - # Path to the Moodle config.php file

 - BACKUP_DIR='/path/to/web-dir-parent/mdl_backup/mdl_bu_files' - # Path to the backup files directory

 - BACKUP_STORE='/path/to/backup_store' - # Path to store backups after creation (optional, if different from BACKUP_DIR)

 - NUM_BACKUPS_TO_KEEP=3 - # Number of backups to retain in each directory

 - SERVICE_NAME='your_service_name' - # Name of the service being backed up

### Sample Configuration File

```conf
MDL_WEB_DIR="/path/to/moodle/web-files"
MDL_CONFIG_PATH="/path/to/moodle/config.php"
BACKUP_DIR="/path/to/backups"
BACKUP_STORE="/path/to/backup/store"
NUM_BACKUPS_TO_KEEP=3
SERVICE_NAME='your_service_name'
```

## Script Structure and Functions

The script file is structured and contains detailed internal documentation (commenting) - please refer to the *mdl_bu.sh* file for detail

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
