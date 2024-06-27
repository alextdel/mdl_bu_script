Sure! Here's a `README.md` file that explains the purpose of the script, how to configure it, and how to run it:

```markdown
# Moodle Backup Script

This script automates the backup of a Moodle database and the Moodledata directory. It extracts the necessary credentials and paths from the `config.php` file of your Moodle installation and performs a database dump and a tarball archive of the Moodledata directory. The script also verifies the backups and retains only the last three backups.

## Prerequisites

- Bash shell
- `mysqldump` utility
- `tar` utility
- Appropriate permissions to read the Moodle `config.php` file and write to the backup directory

## Configuration

Before running the script, update the following variables at the top of the script file:

```bash
# Path to the Moodle config.php file
MDL_CONFIG_PATH='/path/to/moodle/config.php'

# Path to the backup directory
BACKUP_DIR='/path/to/backup'

# Number of backups to retain
NUM_BACKUPS_TO_KEEP=3
```

Replace `/path/to/moodle/config.php` with the actual path to your Moodle `config.php` file. Replace `/path/to/backup` with the path where you want to store the backup files. Adjust `NUM_BACKUPS_TO_KEEP` if you want to retain a different number of backups.

## Usage

1. **Make the script executable**:

    ```bash
    chmod +x backup_script.sh
    ```

2. **Run the script with `sudo`** (if required):

    ```bash
    sudo ./backup_script.sh
    ```

## Script Overview

### Configuration Variables

- **`MDL_CONFIG_PATH`**: Path to the Moodle `config.php` file.
- **`BACKUP_DIR`**: Path to the directory where backups will be stored.
- **`NUM_BACKUPS_TO_KEEP`**: Number of backups to retain.

### Main Script Functions

1. **Check Configuration File**:
    - Verifies the existence and readability of the `config.php` file.
    - Checks for the required configuration variables.

2. **Extract Credentials and Paths**:
    - Extracts database credentials and the Moodledata path from the `config.php` file.

3. **Perform Backups**:
    - Dumps the Moodle database using `mysqldump`.
    - Archives the Moodledata directory using `tar`.

4. **Verify Backups**:
    - Checks if the backup files are non-empty.

5. **Retain Only the Last Three Backups**:
    - Retains only the specified number of the most recent backups.

### Error Handling

The script checks for errors at each step and exits gracefully with an appropriate error message if any operation fails.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
```

### Explanation of the `README.md`:

- **Title and Introduction**: Provides a brief overview of what the script does.
- **Prerequisites**: Lists the requirements for running the script.
- **Configuration**: Explains how to configure the script by setting the necessary variables.
- **Usage**: Provides instructions on how to make the script executable and run it.
- **Script Overview**: Details the main parts of the script, including configuration variables, main functions, and error handling.
- **License**: Mentions the licensing information.

This `README.md` should help users understand how to set up and use the backup script effectively.