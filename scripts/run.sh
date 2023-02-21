#!/bin/bash

set -e
while ! nc -z "${POSTGRES_HOST:-postgres}" "${POSTGRES_PORT:-5432}"; do
  echo "waiting for postgress listening..."
  sleep 0.1
done
echo "PostgreSQL started"

# prepare and restore database
/scripts/create.sh
/scripts/restore.sh

# make env accessible to cron
declare -p | grep -Ev 'BASHOPTS|BASH_VERSINFO|EUID|PPID|SHELLOPTS|UID' > /container.env

# install crontab
sed -e "s#\${BACKUP_SCHEDULE}#$BACKUP_SCHEDULE#" /crontab > /etc/cron.d/scheduler
chmod +x /etc/cron.d/scheduler
crontab /etc/cron.d/scheduler

echo "Starting cron"
cron -f
