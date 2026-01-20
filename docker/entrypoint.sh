#!/usr/bin/env bash
set -e

#######################################
# 基础变量 & 默认值
#######################################

TZ=${TZ:-Asia/Shanghai}

WORLD_NAME=${WORLD_NAME:-world}
WORLD_PATH=${WORLD_PATH:-/worlds}
WORLD_FILE="${WORLD_PATH}/${WORLD_NAME}.wld"

AUTO_CREATE=${AUTO_CREATE:-1}
WORLD_SIZE=${WORLD_SIZE:-2}
DIFFICULTY=${DIFFICULTY:-0}
SEED=${SEED:-}

SERVER_PORT=${SERVER_PORT:-7777}
MAX_PLAYERS=${MAX_PLAYERS:-16}
SERVER_PASSWORD=${SERVER_PASSWORD:-}
LANGUAGE=${LANGUAGE:-en-US}

AUTOSAVE=${AUTOSAVE:-1}

TERRARIA_VERSION=${TERRARIA_VERSION:-1.4.4.9}
TERRARIA_ROOT=/opt/terraria
TERRARIA_BIN=${TERRARIA_ROOT}/TerrariaServer.bin.x86_64

CONFIG_DIR=/config
CONFIG_FILE=${CONFIG_DIR}/server.conf

ENABLE_BACKUP=${ENABLE_BACKUP:-1}
BACKUP_INTERVAL=${BACKUP_INTERVAL:-30}
BACKUP_RETAIN=${BACKUP_RETAIN:-10}
BACKUP_DIR=${BACKUP_DIR:-/backups}

#######################################
# 时区设置
#######################################

if [ -f /usr/share/zoneinfo/$TZ ]; then
  ln -sf /usr/share/zoneinfo/$TZ /etc/localtime
  echo "$TZ" > /etc/timezone
fi

#######################################
# 创建必要目录
#######################################

mkdir -p "$WORLD_PATH" "$CONFIG_DIR" "$TERRARIA_ROOT" "$BACKUP_DIR"

#######################################
# 自动下载 Terraria Server
#######################################

DOWNLOAD_URL="https://terraria.org/api/download/pc-dedicated-server/${TERRARIA_VERSION}.zip"
TMP_DIR=/tmp/terraria-server

if [ ! -f "$TERRARIA_BIN" ]; then
  echo "[INFO] Downloading Terraria Server v${TERRARIA_VERSION}..."

  rm -rf "$TMP_DIR"
  mkdir -p "$TMP_DIR"

  curl -fL "$DOWNLOAD_URL" -o "$TMP_DIR/server.zip"
  unzip -q "$TMP_DIR/server.zip" -d "$TMP_DIR"

  cp "$TMP_DIR/${TERRARIA_VERSION}/Linux/TerrariaServer.bin.x86_64" "$TERRARIA_BIN"
  chmod +x "$TERRARIA_BIN"

  echo "[INFO] Terraria Server installed."
else
  echo "[INFO] Terraria Server already exists, skipping download."
fi

#######################################
# 生成 server.conf
#######################################

if [ ! -f "$CONFIG_FILE" ]; then
  cat > "$CONFIG_FILE" <<EOF
world=$WORLD_FILE
autocreate=$AUTO_CREATE
worldsize=$WORLD_SIZE
difficulty=$DIFFICULTY
port=$SERVER_PORT
maxplayers=$MAX_PLAYERS
language=$LANGUAGE
autosave=$AUTOSAVE
EOF

  [ -n "$SERVER_PASSWORD" ] && echo "password=$SERVER_PASSWORD" >> "$CONFIG_FILE"
  [ -n "$SEED" ] && echo "seed=$SEED" >> "$CONFIG_FILE"
fi

#######################################
# 优雅停服
#######################################

graceful_shutdown() {
  echo "[INFO] Saving world before shutdown..."
  if kill -0 "$SERVER_PID" 2>/dev/null; then
    echo "save" > /proc/${SERVER_PID}/fd/0
    sleep 5
    
    if [ "$ENABLE_BACKUP" = "1" ]; then
      echo "[INFO] Creating final backup before shutdown..."
      /usr/local/bin/backup.sh || true
    fi
  fi
  exit 0
}

trap graceful_shutdown SIGTERM SIGINT

#######################################
# 启动服务器
#######################################

"$TERRARIA_BIN" -config "$CONFIG_FILE" &
SERVER_PID=$!

echo "[INFO] Terraria Server started with PID: $SERVER_PID"

#######################################
# 自动备份（cron，仅调用镜像内的 backup.sh）
#######################################

if [ "$ENABLE_BACKUP" = "1" ]; then
  # 确保备份脚本能拿到必要的环境变量
  export SERVER_PID WORLD_NAME WORLD_PATH BACKUP_DIR BACKUP_RETAIN BACKUP_INTERVAL

  echo "*/${BACKUP_INTERVAL} * * * * root /usr/local/bin/backup.sh >> /var/log/backup.log 2>&1" \
    > /etc/cron.d/terraria-backup

  chmod 0644 /etc/cron.d/terraria-backup
  crontab /etc/cron.d/terraria-backup
  cron
fi

wait "$SERVER_PID"
