#!/usr/bin/env bash
set -euo pipefail

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
  echo "Usage: restore.sh <backup-file.tar.gz>"
  echo "Example:"
  echo "  restore.sh world_20260118_030000.tar.gz"
  exit 1
fi

BACKUP_FILE="$1"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_FILE}"

#######################################
# 安全检查
#######################################

if [ ! -f "$BACKUP_PATH" ]; then
  echo "[ERROR] Backup file not found: $BACKUP_PATH"
  exit 1
fi

# 防止正在运行时恢复
if pgrep -f TerrariaServer >/dev/null; then
  echo "[ERROR] Terraria Server is running."
  echo "Please stop the container before restoring."
  exit 1
fi

#######################################
# 备份当前世界（二次保险）
#######################################

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
SAFETY_BACKUP="${BACKUP_DIR}/${WORLD_NAME}_pre_restore_${TIMESTAMP}.tar.gz"

echo "[INFO] Creating safety backup: $SAFETY_BACKUP"
tar -czf "$SAFETY_BACKUP" "$WORLD_DIR"

#######################################
# 执行恢复
#######################################

echo "[INFO] Restoring world from $BACKUP_FILE ..."

rm -rf "${WORLD_DIR:?}/"*
tar -xzf "$BACKUP_PATH" -C /

echo "[INFO] Restore completed successfully."
echo "[INFO] Previous world backed up as:"
echo "       $SAFETY_BACKUP"
