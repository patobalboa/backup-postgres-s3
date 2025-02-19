# PostgreSQL Backup S3 Service

## 📌 Descripción
Este script automatiza el respaldo de bases de datos PostgreSQL, subiéndolos a Amazon S3 y notificando el estado del backup vía correo electrónico, Slack y Telegram.

## 🚀 Características
- Respaldo automático de bases de datos PostgreSQL.
- Compresión con `gzip` y verificación de integridad con `sha256sum`.
- Subida a Amazon S3 con `aws s3 sync` y cifrado `AES256`.
- Notificaciones configurables por **correo**, **Slack** y **Telegram**.
- Gestión automática de **backups antiguos**.
- **Ejecución automatizada con `systemd.timer`**.

## 📋 Requisitos
- **PostgreSQL Client** (`pg_dump`)
- **AWS CLI** (para subir backups a S3)
- **Sendmail** (para notificaciones por correo)
- **gzip** (para compresión de backups)
- **curl** (para enviar notificaciones a Slack y Telegram)

### 🔧 Instalación de Requisitos
Para instalar las dependencias en **Ubuntu/Debian**, ejecuta:
```bash
sudo apt update && sudo apt install -y postgresql-client awscli sendmail gzip curl
```
En **CentOS/RHEL**, usa:
```bash
sudo yum install -y postgresql awscli sendmail gzip curl
```

## 📦 Instalación
### 1️⃣ Ejecutar el instalador
```bash
sudo bash install_backup.sh
```
Este script:
- Instalará las dependencias necesarias.
- Pedirá los datos de configuración y creará el archivo `/etc/backup_config.conf`.
- Configurará `systemd` para ejecutar el backup automáticamente.

### 2️⃣ Verificar el servicio
Para comprobar que el backup está activo:
```bash
systemctl status backup.service
```
Para ver cuándo se ejecutará el próximo backup:
```bash
systemctl list-timers --all | grep backup.timer
```

## ☁️ Configuración de AWS CLI
Antes de usar el backup, debes configurar AWS CLI con tus credenciales:
```bash
aws configure
```
Introduce:
- **AWS Access Key ID**
- **AWS Secret Access Key**
- **Default region name** (Ejemplo: `us-east-1`)
- **Output format** (Ejemplo: `json` o `table`)

Para verificar la configuración:
```bash
aws s3 ls
```
Si ves una lista de tus buckets, AWS CLI está correctamente configurado.

## 🔧 Configuración
### 📄 Archivo de configuración: `/etc/backup_config.conf`
Ejemplo de configuración:
```ini
DATABASE_NAME="database_name"
DATABASE_USERNAME="postgres"
DATABASE_HOST="localhost"
DATABASE_PORT="5432"
DATABASE_BACKUP_PATH="/var/backups/postgresql"
DATABASE_BACKUP_NAME="database_name-$(date +%Y-%m-%d).backup"

AWS_DEFAULT_REGION="us-east-1"
BUCKET_NAME="backups-bucket"

ENABLE_EMAIL_NOTIFICATION="yes"
ENABLE_SLACK_NOTIFICATION="yes"
ENABLE_TELEGRAM_NOTIFICATION="yes"

LOG_FILE="/var/log/backup_script.log"
BACKUP_TIME="03:00"
RETENTION_DAYS=7
```

## 🔄 Administración
### Iniciar un backup manualmente
```bash
sudo systemctl start backup.service
```

### Ver logs del backup
```bash
journalctl -u backup.service --no-pager --since "1 hour ago"
```

### Modificar la hora del backup
1. Editar `/etc/backup_config.conf` y cambiar `BACKUP_TIME`.
2. Recargar la configuración con:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl restart backup.timer
   ```

## 📢 Notificaciones
### 📧 Notificación por Correo
Si `ENABLE_EMAIL_NOTIFICATION="yes"`, se enviará un correo en caso de éxito o fallo del backup.

### 🔔 Notificación por Slack
Si `ENABLE_SLACK_NOTIFICATION="yes"`, se enviará un mensaje al **webhook de Slack** configurado en `SLACK_WEBHOOK_URL`.

### 📲 Notificación por Telegram
Si `ENABLE_TELEGRAM_NOTIFICATION="yes"`, se enviará un mensaje al **bot de Telegram** configurado en `TELEGRAM_BOT_TOKEN` y `TELEGRAM_CHAT_ID`.

## ❌ Desinstalación
Si deseas eliminar el backup automático:
```bash
sudo systemctl disable --now backup.timer
sudo systemctl disable --now backup.service
sudo rm -f /etc/systemd/system/backup.timer /etc/systemd/system/backup.service
sudo rm -f /usr/local/bin/backup_postgres.sh /etc/backup_config.conf
```

## 🎯 Contribuciones
Si tienes mejoras o encuentras errores, ¡haz un **pull request** o crea un **issue** en GitHub! 🚀
