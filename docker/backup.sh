#!/usr/bin/env bash
set -e

TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/${WORLD_NAME}-${TIMESTAMP}.tar.gz"
SCREEN_SESSION=${SCREEN_SESSION:-terraria}

# 确认 screen 会话存在
if screen -ls | grep -q "\.${SCREEN_SESSION}[[:space:]]"; then
  echo "[BACKUP] Notifying players via screen session: ${SCREEN_SESSION}"

  # 通过 screen 注入命令（注意 CR）
  screen -S "${SCREEN_SESSION}" -p 0 -X stuff "say [Backup] The world is being backed up, please wait..."$'\r' || true
  sleep 2

  echo "[BACKUP] Saving world via screen..."
  screen -S "${SCREEN_SESSION}" -p 0 -X stuff "save"$'\r' || true
  sleep 5

  # 备份完成提示
  screen -S "${SCREEN_SESSION}" -p 0 -X stuff "say [Backup] Backup completed!"$'\r' || true
else
  echo "[BACKUP] WARNING: screen session '${SCREEN_SESSION}' not found, skipping in-game save commands."
fi

echo "[BACKUP] Creating backup: ${BACKUP_FILE}"
tar -czf "$BACKUP_FILE" -C "$WORLD_PATH" .

echo "[BACKUP] Cleaning old backups..."
ls -1t ${BACKUP_DIR}/*.tar.gz | tail -n +$((BACKUP_RETAIN + 1)) | xargs -r rm --

echo "[BACKUP] Backup complete."
