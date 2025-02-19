#!/bin/bash
# PostgreSQL Backup Script with S3 Upload and Notifications

CONFIG_FILE="/etc/backup_config.conf"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file not found at $CONFIG_FILE"
    exit 1
fi
source "$CONFIG_FILE"

# Functions
send_mail() {
    local status=$1
    local subject message
    if [ "$status" -eq 0 ]; then
        subject="Backup Success: $DATABASE_NAME"
        message="Backup completed successfully."
    else
        subject="Backup Failure: $DATABASE_NAME"
        message="Backup encountered an error."
    fi
    if [ "$ENABLE_EMAIL_NOTIFICATION" = "yes" ]; then
        echo -e "Subject: $subject\n\n$message" | /usr/sbin/sendmail -v -f "$SENDMAIL_FROM" "$SENDMAIL_TO"
    fi
}

send_slack_notification() {
    local message="$1"
    if [ "$ENABLE_SLACK_NOTIFICATION" = "yes" ] && [ -n "$SLACK_WEBHOOK_URL" ]; then
        curl -X POST -H 'Content-type: application/json' --data "{\"text\":\"$message\"}" "$SLACK_WEBHOOK_URL"
    fi
}

send_telegram_notification() {
    local message="$1"
    if [ "$ENABLE_TELEGRAM_NOTIFICATION" = "yes" ] && [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
        curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
        -d "chat_id=$TELEGRAM_CHAT_ID&text=$message"
    fi
}

log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

backup_database() {
    log "Starting backup for database $DATABASE_NAME"
    pg_dump -U "$DATABASE_USERNAME" -h "$DATABASE_HOST" -p "$DATABASE_PORT" -F c -b -v -f "$DATABASE_BACKUP_PATH/$DATABASE_BACKUP_NAME" "$DATABASE_NAME"
    if [ $? -eq 0 ]; then
        log "Database backup successful"
    else
        log "Database backup failed"
        send_mail 1
        send_slack_notification "Database backup failed for $DATABASE_NAME"
        send_telegram_notification "Database backup failed for $DATABASE_NAME"
        exit 1
    fi

    gzip -c "$DATABASE_BACKUP_PATH/$DATABASE_BACKUP_NAME" > "$DATABASE_BACKUP_PATH/$DATABASE_BACKUP_NAME.gz"
    sha256sum "$DATABASE_BACKUP_PATH/$DATABASE_BACKUP_NAME.gz" > "$DATABASE_BACKUP_PATH/$DATABASE_BACKUP_NAME.sha256"
}

upload_to_s3_and_cleanup() {
    log "Uploading backup to S3"
    if aws s3 sync "$DATABASE_BACKUP_PATH" "s3://$BUCKET_NAME/" --delete --sse AES256; then
        log "S3 upload successful"
        find "$DATABASE_BACKUP_PATH" -name "*.backup.gz" -type f -mtime +$RETENTION_DAYS -exec rm {} \;
    else
        log "S3 upload failed"
        send_mail 1
        send_slack_notification "S3 upload failed for $DATABASE_NAME"
        send_telegram_notification "S3 upload failed for $DATABASE_NAME"
        exit 1
    fi
}

if [ "$(id -u)" != "0" ]; then
    log "This script must be run as root"
    send_mail 1
    send_slack_notification "Backup script requires root permissions"
    send_telegram_notification "Backup script requires root permissions"
    exit 1
fi

if [ ! -d "$DATABASE_BACKUP_PATH" ]; then
    log "Creating backup directory $DATABASE_BACKUP_PATH"
    mkdir -p "$DATABASE_BACKUP_PATH"
fi

backup_database
upload_to_s3_and_cleanup

log "Backup process completed successfully"
send_mail 0
send_slack_notification "Backup and upload successful for $DATABASE_NAME"
send_telegram_notification "Backup and upload successful for $DATABASE_NAME"

exit 0
