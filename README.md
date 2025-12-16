# MySQL Backup to AWS S3 (Streamed, No Local File)

This script performs a compressed backup of all MySQL databases and streams the dump directly to an AWS S3 bucket, without ever writing a full dump file to local disk. It’s designed for servers with limited storage or environments where you want backups off the machine as quickly and reliably as possible. 

---

## Features

- Streams `mysqldump` → `gzip` → `aws s3 cp` with no large local `.sql` file. 
- Backs up **all databases** in one run using `--all-databases`. 
- Includes routines, triggers, and events for more complete backups (`--routines --triggers --events`). 
- Uses safe Bash defaults: `set -euo pipefail` and strict `IFS`.
- Logs to a timestamped log file with clear success/failure messages.
- Exits non‑zero if any part of the pipeline fails (dump, gzip, or S3 upload).

---

## Configuration

Edit these variables near the top of the script to match your environment:

```
AWS_BUCKET="INSERT_AWS_BUCKET_HERE"      # e.g. my-db-backups/prod (no s3:// prefix)
MYSQL_CNF="/path/to/.mysql_p"           # e.g. /home/dbuser/.mysql_p
LOG_FILE="/var/log/db_backups/mysql_all_backup_$RUN_TIME.log"
```

Optional:

```
export TZ=${TZ:-UTC}  # Set your timezone if desired
```

The MySQL credentials file (`$MYSQL_CNF`) should contain the usual `mysqldump` options, for example:

```
[client]
user=backup_user
password=strong_password_here
host=localhost
```

Make sure it is protected:

```
chmod 600 /path/to/.mysql_p
```

---

## How It Works

The core backup pipeline:

```
mysqldump --defaults-extra-file="$MYSQL_CNF" \
  --single-transaction --routines --triggers --events \
  --verbose --all-databases \
  | gzip -c \
  | aws s3 cp - "s3://$AWS_BUCKET/$BACKUP_NAME" --only-show-errors
```

- `mysqldump` creates a consistent snapshot of all databases, especially when using `--single-transaction` with InnoDB.
- `gzip` compresses the output on the fly.
- `aws s3 cp -` streams the compressed dump straight into S3 from stdin using the `-` argument.

If any part of this pipeline fails, the script logs the error and exits with status `1`.

---

## Usage

1. Copy the script to your server, for example:

   ```
   /usr/local/bin/mysql_s3_stream_backup.sh
   ```

2. Make it executable:

   ```
   chmod +x /usr/local/bin/mysql_s3_stream_backup.sh
   ```

3. Test a manual run:

   ```
   /usr/local/bin/mysql_s3_stream_backup.sh
   ```

   Check the log file (default):

   ```
   ls -1 /var/log/db_backups/
   tail -n 50 /var/log/db_backups/mysql_all_backup_*.log
   ```

4. Schedule via cron (example: nightly at 2 AM):

   ```
   crontab -e

   0 2 * * * /usr/local/bin/mysql_s3_stream_backup.sh
   ```

---

## Notes and Recommendations

- Use S3 lifecycle rules for **retention** (for example, keep 30 days of backups, then transition or delete older ones).
- Periodically test restoring from an S3 backup to verify everything works end‑to‑end.
- Adjust `mysqldump` options if needed (for example, remove `--routines/--events` if your environment doesn’t use them).
- Ensure the user running the script has:
  - Permission to read `$MYSQL_CNF`.
  - Permission to write to `LOG_FILE` and its directory.
  - AWS IAM permissions to `s3:PutObject` (and optionally `s3:ListBucket`) on the target bucket/prefix.
## License

MIT License – you are free to use, modify, and distribute this script, including in commercial environments, as long as the license and copyright notice are kept.
See the [`LICENSE`](./LICENSE) file for full text.
