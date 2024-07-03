# Moodle Backup Script

This script automates the backup of a Moodle instance, including its database and `moodledata` directory. Configuration is managed through separate configuration files.

When the script is run successfully, the output will be:
```
-rw-r--r-- 1 user user 4231656 Jun 28 09:27 moodledata_backup_YYYYMMDDtttt.tar.gz
-rw-r--r-- 1 user user 1669354 Jun 28 09:27 moodle_db_backup_YYYYMMDDtttt.sql
-rw-r--r-- 1 user user       0 Jun 28 09:27 moodle_db_backup_YYYYMMDDtttt.sql.err
```
A successful database dump will generate a .sql.err file with zero size/contents.

## Configuration Files

### `mdl_bu.conf.template`
This is the template configuration file. Copy this file to `mdl_bu.conf` and update it with instance-specific values.

### `mdl_bu.conf`
This file contains instance-specific configuration values. It is created by copying `mdl_bu.conf.template` and updating the paths and other settings. This file is not part of the git repo.

## Main Script File: `mdl_bu.sh`
The main script reads configuration variables from `mdl_bu.conf` and performs the backup operations.

## Backup Storage
Backups are stored in the directory specified in the `mdl_bu.conf` file. Ensure that this directory exists and has the appropriate permissions before running the script.

### Location of Backup Directory:
- Do not place the backup directory inside the web folder (public_html or equivalent).
- Create a directory (and set it in the `mdl_bu.conf` file) in the same domain folder as the website directory. Often this will be the same place as the `moodledata` folder, e.g.:
```
domain_dir
 |-- moodledata
 |-- *mdl_backup*
 \-- public_html
```

## Quickstart

Follow these steps to use the backup script:

1. **Create the `mdl_backup` and `mdl_bu_files` directories:**
   The script will attempt to create the backup files directory, but it is better to set this up first. Note: the script and `mdl_bu_files` need to be in parallel directories as the git requires an empty directory for cloning the local repo.
   ```
   mkdir -p /path/to/web-dir-parent/mdl_backup/mdl_bu_files
   cd /path/to/web-dir-parent/mdl_backup
   ```

2. **Clone the repository:**
   While in `/path/to/web-dir-parent/mdl_backup`:
   ```
   git clone <repository-url>  # a sub-dir for the git repo is made e.g., 'mdl_bu_script'
   cd <repository-directory>
   ```

3. **Copy the template configuration file:**
   ```
   cp mdl_bu.conf.template mdl_bu.conf
   ```

4. **Edit `mdl_bu.conf` with your instance-specific values:**
   ```
   nano mdl_bu.conf
   # Update the paths and settings as needed
   ```

5. **Ensure the backup directory exists and has the correct permissions:**
   ```
   mkdir -p /path/to/your/backup
   chmod 755 /path/to/your/backup
   ```

6. **Make the script file executable:**
   ```
   chmod +x mdl_bu.sh
   ```

7. **Ensure the MariaDB/MySQL db permissions are correct:**
   ```
   mysql -u root -p
   Enter password: 

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
   ```
   ./mdl_bu.sh
   ```

9. **Verify the backup process completion message:**
   - Ensure that you see messages indicating the success of database and moodledata backups.
   - Check the backup directory to confirm the presence of the backup files.

## Notes
- The script handles the creation of the backup directory if it does not exist. However, it is recommended to manually ensure the directory exists and has the correct permissions.
- The number of backups to retain is specified in the `mdl_bu.conf` file. Older backups exceeding this number will be deleted automatically.

This process separates configuration from the main script, making it easier to manage instance-specific settings without modifying the script itself.
```
