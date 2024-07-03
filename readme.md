# Moodle Backup Script

This script automates the backup of a Moodle instance, including its database and `moodledata` directory. Configuration is managed through separate configuration files.

When the script is run successfully, the output will show the following backup files, including the associated log file, created with timestamps:

```
-rw-r--r-- 1 user user 4231656 Jun 28 09:27 your_service_name_moodledata_backup_YYYYMMDDHHMMSS.tar.gz
-rw-r--r-- 1 user user 1669354 Jun 28 09:27 your_service_name_db_backup_YYYYMMDDHHMMSS.sql
-rw-r--r-- 1 user user 1669354 Jun 28 09:27 your_service_name_backup_log_YYYYMMDDHHMMSS.txt
```

Note: The log file will contain the same information as the CLI output if this script is run manually.

## Running the Script

1. **From the Terminal:**

    ```sh
    cd /path/to/the/directory_containing_script
    ./mdl_bu.sh
    ```

    Note: Depending on user permissions, **sudo** may be required.

2. **From a Cron Job:**

    This script can be run automatically using the Linux cron system. The following shows how to set up a daily backup at 2:30 AM.

    1. **Open the crontab file for editing:**

        ```sh
        crontab -e
        ```

    2. **Add a new cron job entry:**

        Add the following line to schedule the `mdl_bu.sh` script to run daily at 2:30 AM. Make sure to replace `/path/to/mdl_bu.sh` with the actual path to your script.

        ```sh
        30 2 * * * /path/to/mdl_bu.sh >> /path/to/web-dir-parent/mdl_backup/mdl_bu_files/backup_cron_log.txt 2>&1
        ```

        This line breaks down as follows:
        - `30 2 * * *` specifies the schedule (2:30 AM every day).
        - `/path/to/mdl_bu.sh` is the path to your backup script.
        - `>> /path/to/web-dir-parent/mdl_backup/mdl_bu_files/backup_cron_log.txt 2>&1` appends both the standard output and standard error of the script to `backup_cron_log.txt`.

    3. **Save and exit the crontab editor:**

        - If you're using `nano` as the editor, press `Ctrl+X`, then `Y` to confirm, and `Enter` to save the changes.

    4. **Verify the cron job:**

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
- First, generated into the `BACKUP_DIR` location defined in the `mdl_bu.conf` file - this is the local copy of the backup files.
- Second, copied to the `BACKUP_STORE` location defined in the `mdl_bu.conf` file - this is the remote backup version stored in Azure Blob Storage.

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

---

## Quickstart

Follow these steps to use the backup script:

1. **Create the `mdl_backup` and `mdl_bu_files` directories:**

    The script will attempt to create the backup files directory, but it is better to set this up first:

    ```sh
    mkdir -p /path/to/web-dir-parent/mdl_backup/mdl_bu_files
    cd /path/to/web-dir-parent/mdl_backup
    ```

2. **Clone the repository:**

    While in `/path/to/web-dir-parent/mdl_backup`:

    ```sh
    git clone <repository-url>  # a sub-directory for the git repo is made e.g., 'mdl_bu_script'
    cd <repository-directory>
    ```

3. **Copy the template configuration file:**

    ```sh
    cp mdl_bu.conf.template mdl_bu.conf
    ```

4. **Edit `mdl_bu.conf` with your instance-specific values:**

    ```sh
    nano mdl_bu.conf
    # Update the paths and settings as needed
    ```

5. **Ensure the backup directory exists and has the correct permissions:**

    ```sh
    mkdir -p /path/to/web-dir-parent/mdl_backup/mdl_bu_files
    chmod 755 /path/to/web-dir-parent/mdl_backup/mdl_bu_files
    ```

6. **Make the script file executable:**

    ```sh
    chmod +x mdl_bu.sh
    ```

7. **Ensure the MariaDB/MySQL DB permissions are correct:**

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

8. **Run the backup script:**

    ```sh
    ./mdl_bu.sh
    ```

9. **Verify the backup process completion message:**

    - Ensure that you see messages indicating the success of database and moodledata backups.
    - Check the backup directory to confirm the presence of the backup files.

## Notes

- The script handles the creation of the backup directory if it does not exist. However, it is recommended to manually ensure the directory exists and has the correct permissions.
- The number of backups to retain is specified in the `mdl_bu.conf` file. Older backups exceeding this number will be deleted automatically.
