#!/usr/bin/env bash
set -e

TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/${WORLD_NAME}-${TIMESTAMP}.tar.gz"

echo "[BACKUP] Saving world..."
echo "save" > /proc/${SERVER_PID}/fd/0
sleep 5

echo "[BACKUP] Creating backup: ${BACKUP_FILE}"
tar -czf "$BACKUP_FILE" -C "$WORLD_PATH" .

echo "[BACKUP] Cleaning old backups..."
ls -1t ${BACKUP_DIR}/*.tar.gz | tail -n +$((BACKUP_RETAIN + 1)) | xargs -r rm --

echo "[BACKUP] Backup complete."
