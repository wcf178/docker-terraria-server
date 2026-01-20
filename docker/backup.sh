#!/usr/bin/env bash
set -e

TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/${WORLD_NAME}-${TIMESTAMP}.tar.gz"

# 如果没有从外部注入 SERVER_PID，则尝试自动查找 Terraria 进程
if [ -z "${SERVER_PID:-}" ]; then
  # 优先匹配专用服二进制名称
  SERVER_PID=$(pgrep -f 'TerrariaServer.bin.x86_64' || true)
  # 回退匹配通用名称（避免匹配到 restore/backup 自身）
  if [ -z "${SERVER_PID}" ]; then
    SERVER_PID=$(pgrep -f 'TerrariaServer( |$)' || true)
  fi
fi

if [ -n "${SERVER_PID:-}" ] && kill -0 "${SERVER_PID}" 2>/dev/null; then
  echo "[BACKUP] Notifying players..."
  
  # 发送备份提醒
  echo "say [Backup] The world is being backed up, please wait..." > "/proc/${SERVER_PID}/fd/0"
  sleep 2
  
  echo "[BACKUP] Saving world (PID=${SERVER_PID})..."
  echo "save" > "/proc/${SERVER_PID}/fd/0"
  sleep 5
  
  # 可选：备份完成提示
  echo "say [Backup] Backup completed!" > "/proc/${SERVER_PID}/fd/0"
else
  echo "[BACKUP] WARNING: SERVER_PID is not set or process not found, skipping in-game save."
fi

echo "[BACKUP] Creating backup: ${BACKUP_FILE}"
tar -czf "$BACKUP_FILE" -C "$WORLD_PATH" .

echo "[BACKUP] Cleaning old backups..."
ls -1t ${BACKUP_DIR}/*.tar.gz | tail -n +$((BACKUP_RETAIN + 1)) | xargs -r rm --

echo "[BACKUP] Backup complete."
