#!/bin/bash

# Check if another instance of script is running
pidof -o %PPID -x $0 >/dev/null && echo "ERROR: Script $0 already running" && exit 1

set -e

echo "Backing up database"

export AWS_ACCESS_KEY_ID=$BACKUP_KEY
export AWS_SECRET_ACCESS_KEY=$BACKUP_SECRET
export PGPASSWORD=$POSTGRES_PASSWORD

pg_dump --format=custom \
        -h "${POSTGRES_HOST:-postgres}" \
        -p "${POSTGRES_PORT:-5432}" \
        -U $POSTGRES_USER \
        -d $POSTGRES_DATABASE \
        $PGDUMP_EXTRA_OPTS \
        > db.dump

timestamp=$(date +"%Y-%m-%dT%H:%M:%S")
s3_uri_base="s3://${BACKUP_PATH}"
aws_args="--endpoint-url https://s3.filebase.com"

s3_uri="${s3_uri_base}/${POSTGRES_DATABASE}_${timestamp}.dump"

if [ -n "$BACKUP_PASSPHRASE" ]; then
  echo "Encrypting backup..."
  gpg --symmetric --batch --passphrase "$BACKUP_PASSPHRASE" db.dump
  rm db.dump
  local_file="db.dump.gpg"
  s3_uri="${s3_uri}.gpg"
else
  local_file="db.dump"
  s3_uri="$s3_uri"
fi

echo "Uploading backup to $BACKUP_PATH..."
aws $aws_args s3 cp "$local_file" "$s3_uri"
rm "$local_file"

deleteAfter="${BACKUP_RETAIN:-"10 days"}"
echo "Deleting backups older than $deleteAfter"

aws $aws_args s3 ls "${s3_uri_base}/${POSTGRES_DATABASE}" | while read -r line;  do
createDate=`echo $line|awk {'print $1" "$2'}`
createDate=`date -d"$createDate" +%s`
olderThan=`date -d"-$deleteAfter" +%s`
if [[ $createDate -lt $olderThan ]]
then
  fileName=`echo $line|awk '{$1=$2=$3=""; print $0}' | sed 's/^[ \t]*//'`
  if [[ $fileName != "" ]]
  then
    aws $aws_args s3 rm "${s3_uri_base}/$fileName"
  fi
fi
done;

echo "Backup complete."
