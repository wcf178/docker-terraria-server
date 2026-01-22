#!/usr/bin/env bash
set -e

# 设置日志文件
LOG_FILE="/var/log/backup.log"

# 日志函数
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') [BACKUP] $*" | tee -a "$LOG_FILE"
}

TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
BACKUP_FILE="${CONTAINER_BACKUP_DIR}/${WORLD_NAME}-${TIMESTAMP}.tar.gz"
SCREEN_SESSION=${SCREEN_SESSION:-terraria}

# 确认 screen 会话存在
if screen -ls | grep -q "\.${SCREEN_SESSION}[[:space:]]"; then
  log "Notifying players via screen session: ${SCREEN_SESSION}"

  # 通过 screen 注入命令（注意 CR）
  screen -S "${SCREEN_SESSION}" -p 0 -X stuff "say [Backup] The world is being backed up, please wait..."$'\r' || true
  sleep 2

  log "Saving world via screen..."
  screen -S "${SCREEN_SESSION}" -p 0 -X stuff "save"$'\r' || true
  sleep 5

  # 备份完成提示
  screen -S "${SCREEN_SESSION}" -p 0 -X stuff "say [Backup] Backup completed!"$'\r' || true
else
  # 如果是关闭时的备份，不显示警告（这是正常的）
  if [ "${SHUTDOWN_BACKUP:-0}" != "1" ]; then
    log "WARNING: screen session '${SCREEN_SESSION}' not found, skipping in-game save commands."
  else
    log "Server already shut down, proceeding with file backup..."
  fi
fi

log "Creating backup: ${BACKUP_FILE}"
tar -czf "$BACKUP_FILE" -C "$CONTAINER_WORLD_PATH" .

log "Cleaning old backups..."
ls -1t ${CONTAINER_BACKUP_DIR}/*.tar.gz | tail -n +$((BACKUP_RETAIN + 1)) | xargs -r rm --

log "Backup complete."
