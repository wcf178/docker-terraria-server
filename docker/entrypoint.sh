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

TERRARIA_VERSION=${TERRARIA_VERSION:-1449}
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

TERRARIA_VERSION_NUM=$(echo "${TERRARIA_VERSION}" | tr -d '.')
TMP_DIR=/tmp/terraria-server

# 定义多个可能的下载源（按优先级）
DOWNLOAD_URLS=(
  "https://terraria.org/api/download/pc-dedicated-server/terraria-server-${TERRARIA_VERSION}.zip"
  "https://terraria.org/system/dedicated_servers/archives/000/000/042/original/terraria-server-${TERRARIA_VERSION_NUM}.zip"
  "https://github.com/Terraria/Terraria/releases/download/${TERRARIA_VERSION}/TerrariaServer-${TERRARIA_VERSION}.zip"
)

if [ ! -f "$TERRARIA_BIN" ]; then
  echo "[INFO] Downloading Terraria Server v${TERRARIA_VERSION}..."
  
  rm -rf "$TMP_DIR"
  mkdir -p "$TMP_DIR"
  
  # 尝试每个下载源
  for i in "${!DOWNLOAD_URLS[@]}"; do
    URL="${DOWNLOAD_URLS[$i]}"
    echo "[INFO] Trying download source $((i+1)): $URL"
    
    if curl -fL "$URL" -o "$TMP_DIR/server.zip" && unzip -tq "$TMP_DIR/server.zip" >/dev/null 2>&1; then
      echo "[INFO] Download successful from source $((i+1))"
      break
    else
      echo "[WARN] Download failed from source $((i+1))"
      rm -f "$TMP_DIR/server.zip"
    fi
  done
  
  if [ ! -f "$TMP_DIR/server.zip" ]; then
    echo "[ERROR] All download sources failed!"
    exit 1
  fi
  
  # 解压
  unzip -q "$TMP_DIR/server.zip" -d "$TMP_DIR"
  
  # 查找二进制文件（支持多种目录结构）
  find_binary() {
    local base_dir="$1"
    local paths=(
      "Linux/TerrariaServer.bin.x86_64"
      "TerrariaServer.bin.x86_64"
      "${TERRARIA_VERSION_NUM}/Linux/TerrariaServer.bin.x86_64"
      "terraria-server-${TERRARIA_VERSION_NUM}/Linux/TerrariaServer.bin.x86_64"
    )
    
    for rel_path in "${paths[@]}"; do
      if [ -f "${base_dir}/${rel_path}" ]; then
        echo "${base_dir}/${rel_path}"
        return 0
      fi
    done
    return 1
  }
  
  BIN_PATH=$(find_binary "$TMP_DIR")
  
  if [ -n "$BIN_PATH" ]; then
    cp "$BIN_PATH" "$TERRARIA_BIN"
    chmod +x "$TERRARIA_BIN"
    echo "[INFO] Terraria Server installed from: $(basename "$BIN_PATH")"
  else
    echo "[ERROR] Could not find TerrariaServer binary!"
    echo "[DEBUG] Extracted files:"
    find "$TMP_DIR" -type f | grep -i terraria | head -20
    exit 1
  fi
  
  # 清理临时文件
  rm -rf "$TMP_DIR"
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
