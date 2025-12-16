#!/bin/bash
################################################################################
# MySQL Backup to AWS S3                                                       #
# ---------------------------------------------------------------------------- #
# This script performs a compressed backup of all MySQL databases              #
# and streams it directly to an S3 bucket without using local disk space.      #
# The only requirement is to have AWS CLI installed and setup for the user     #
# That is uploading to AWS.                                                    #
# Requires: mysqldump, gzip, and AWS CLI configured with S3 write access.      #
#                                                                              #
# Original Author: Zack Farmer                                                 #
# Create Date: August 2025                                                     #
################################################################################
# The two below commands are to help this command be a bit more strict.        #
# set -euo pipefail                                                            #
#  - -e(errexit) says if anything returns a non 0(success) exit code to quit   #
#  immediately                                                                 #
#  - -u(nounset) Treats undefined variables as an error. So Script will stop on#
#  an undefined variable                                                       #
#  - -o pipefail Normally bash only cares about the last command pipefile fails#
#  if ANY command fails, So if gzip fails, or if s3 copy fails the script wont #
#  think the backup worked.                                                    #
################################################################################
# IFS=$'\n\t'                                                                  #
# - Internal Field Separator                                                   #
# - This prevents word splitting bugs like spaces in the names of things.      #
# - This probably ISNT required. But incase we ever get some wonky filenames   #
# - For example. If the script splits My File.sql into my and file.sql this    #
# will prevent that and only split at newlines or tabs.                        #
################################################################################

set -euo pipefail
IFS=$'\n\t'

export TZ=${TZ:-UTC}  # or set your timezone here
RUN_TIME=$(date +"%m-%d-%Y_%I-%M-%S_%p")
AWS_BUCKET="INSERT_AWS_BUCKET_HERE" #Insert your AWS bucket here. Example: backups/prod
BACKUP_NAME="backup_all_$RUN_TIME.sql.gz"
MYSQL_CNF="/path/to/.mysql_p" #Insert the path to your mysql_cnf file. Example: /home/database/.mysql_p
LOG_FILE="/var/log/db_backups/mysql_all_backup_$RUN_TIME.log" #You can edit the path to your log file. Example: /var/log/db_backups/mysql_backups_$RUN_TIME.log

# Creates the logging directory if it doesnt exist.
LOG_DIR=$(dirname "$LOG_FILE")
mkdir -p "$LOG_DIR"

log() {
  echo "[$(date +'%F %T')] $*" | tee -a "$LOG_FILE"
}

#Validates we have the correct commands available.
for cmd in mysqldump aws gzip; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    log "ERROR: Required command '$cmd' not found in PATH."
    exit 1
  fi
done

log "==== STARTING BACKUP SCRIPT ===="

# Validate config
if [[ -z "$AWS_BUCKET" ]]; then
  log "ERROR: AWS_BUCKET is not set."
  exit 1
else
 log "SUCCESS: AWS_BUCKET is set to $AWS_BUCKET"
fi

# Validate MySQL credentials file
if [[ ! -f "$MYSQL_CNF" ]]; then
  log "ERROR: MySQL credentials file $MYSQL_CNF not found."
  exit 1
else
 log "SUCCESS: MySQL credentials file $MYSQL_CNF was found"
fi

# Run the MySQL dump and backup to AWS S3
if { mysqldump --defaults-extra-file="$MYSQL_CNF" \
  --single-transaction --routines --triggers --events \
  --verbose --all-databases \
 | gzip -c \
 | aws s3 cp - "s3://$AWS_BUCKET/$BACKUP_NAME" --only-show-errors; } >> "$LOG_FILE" 2>&1; then
   log "Backup succeeded: s3://$AWS_BUCKET/$BACKUP_NAME"
  exit 0
else
  log "Backup failed."
  exit 1
fi
