#!/bin/bash
# Install script for PostgreSQL backup service

CONFIG_FILE="/etc/backup_config.conf"
SERVICE_FILE="/etc/systemd/system/backup.service"
BACKUP_SCRIPT="/usr/local/bin/backup_postgres.sh"
LOG_FILE="/var/log/backup_script.log"
TIMER_FILE="/etc/systemd/system/backup.timer"

# Check if run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Exiting."
    exit 1
fi

# Install required packages for ubuntu y debian
if [ -f /etc/debian_version ]; then
    apt update && apt install -y postgresql-client awscli sendmail gzip
fi

# Install required packages for centos and fedora
if [ -f /etc/redhat-release ]; then
    yum install -y postgresql aws-cli sendmail gzip
fi


# Prompt for configuration
read -p "Enter database name: " DB_NAME
read -p "Enter database username: " DB_USER
read -p "Enter database host (default: localhost): " DB_HOST
DB_HOST=${DB_HOST:-localhost}
read -p "Enter database port (default: 5432): " DB_PORT
DB_PORT=${DB_PORT:-5432}
read -p "Enter S3 bucket name: " BUCKET_NAME
read -p "Enter AWS region: " AWS_REGION
read -p "Enable email notifications? (yes/no): " ENABLE_EMAIL
read -p "Enable Slack notifications? (yes/no): " ENABLE_SLACK
read -p "Enable Telegram notifications? (yes/no): " ENABLE_TELEGRAM
read -p "At what time should the backup run daily? (HH:MM, 24-hour format): " BACKUP_TIME

# Create configuration file
echo "Creating configuration file at $CONFIG_FILE"
cat <<EOL > $CONFIG_FILE
DATABASE_NAME="$DB_NAME"
DATABASE_USERNAME="$DB_USER"
DATABASE_HOST="$DB_HOST"
DATABASE_PORT="$DB_PORT"
DATABASE_BACKUP_PATH="/var/backups/postgresql"
DATABASE_BACKUP_NAME="\$DATABASE_NAME-\$(date +%Y-%m-%d).backup"

AWS_DEFAULT_REGION="$AWS_REGION"
BUCKET_NAME="$BUCKET_NAME"

ENABLE_EMAIL_NOTIFICATION="$ENABLE_EMAIL"
ENABLE_SLACK_NOTIFICATION="$ENABLE_SLACK"
ENABLE_TELEGRAM_NOTIFICATION="$ENABLE_TELEGRAM"

LOG_FILE="$LOG_FILE"
BACKUP_TIME="$BACKUP_TIME"
EOL

# Copy the backup script to /usr/local/bin
cp backup_postgres.sh $BACKUP_SCRIPT
chmod +x $BACKUP_SCRIPT

# Create systemd service
echo "Creating systemd service file at $SERVICE_FILE"
cat <<EOL > $SERVICE_FILE
[Unit]
Description=PostgreSQL Backup Service
After=network.target postgresql.service

[Service]
Type=simple
ExecStart=$BACKUP_SCRIPT
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOL

# Create systemd timer
echo "Creating systemd timer file at $TIMER_FILE"
cat <<EOL > $TIMER_FILE
[Unit]
Description=Run PostgreSQL Backup Daily at $BACKUP_TIME

[Timer]
OnCalendar=*-*-* $BACKUP_TIME:00
Persistent=true

[Install]
WantedBy=timers.target
EOL

# Enable and start the timer
systemctl daemon-reload
systemctl enable --now backup.timer

echo "Installation complete. Backup service is scheduled daily at $BACKUP_TIME."