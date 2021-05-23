#!/bin/bash

# Check if another instance of script is running
pidof -o %PPID -x $0 >/dev/null && echo "ERROR: Script $0 already running" && exit 1

set -e

echo "Creating database"

export PGPASSWORD=$POSTGRES_PASSWORD

echo "SELECT 'CREATE DATABASE $POSTGRES_DATABASE' \
  WHERE NOT EXISTS \
  (SELECT FROM pg_database WHERE datname = '$POSTGRES_DATABASE')\gexec" |
    psql -h postgres -p 5432 -U $POSTGRES_USER
