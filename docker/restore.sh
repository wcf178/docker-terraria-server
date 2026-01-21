#!/usr/bin/env bash
set -euo pipefail

# 设置日志文件
LOG_FILE="/var/log/restore.log"

# 日志函数
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') [RESTORE] $*" | tee -a "$LOG_FILE"
}

#######################################
# 基础变量
#######################################

WORLD_DIR=${WORLD_PATH:-/worlds}
BACKUP_DIR=${BACKUP_DIR:-/backups}
WORLD_NAME=${WORLD_NAME:-world}

#######################################
# 参数检查
#######################################

if [ $# -ne 1 ]; then
  log "Usage: restore.sh <backup-file.tar.gz>"
  log "Example:"
  log "  restore.sh world_20260118_030000.tar.gz"
  exit 1
fi

BACKUP_FILE="$1"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_FILE}"

#######################################
# 安全检查
#######################################

if [ ! -f "$BACKUP_PATH" ]; then
  log "[ERROR] Backup file not found: $BACKUP_PATH"
  exit 1
fi

# 防止正在运行时恢复
if pgrep -f TerrariaServer >/dev/null; then
  log "[ERROR] Terraria Server is running."
  log "Please stop the container before restoring."
  exit 1
fi

#######################################
# 备份当前世界（二次保险）
#######################################

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
SAFETY_BACKUP="${BACKUP_DIR}/${WORLD_NAME}_pre_restore_${TIMESTAMP}.tar.gz"

log "[INFO] Creating safety backup: $SAFETY_BACKUP"
tar -czf "$SAFETY_BACKUP" "$WORLD_DIR"

#######################################
# 执行恢复
#######################################

log "[INFO] Restoring world from $BACKUP_FILE ..."

rm -rf "${WORLD_DIR:?}/"*
mkdir -p "$WORLD_DIR"
tar -xzf "$BACKUP_PATH" -C "$WORLD_DIR"

log "[INFO] Restore completed successfully."
log "[INFO] Previous world backed up as:"
log "       $SAFETY_BACKUP"
