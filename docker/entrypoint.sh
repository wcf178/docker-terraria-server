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

CONFIG_DIR=/config
CONFIG_FILE=${CONFIG_DIR}/server.conf

SERVER_BIN=/opt/terraria/TerrariaServer.bin.x86_64

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

mkdir -p "$WORLD_PATH"
mkdir -p "$CONFIG_DIR"

#######################################
# 生成 server.conf（仅在不存在时）
#######################################

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Generating server.conf ..."

  cat > "$CONFIG_FILE" <<EOF
world=$WORLD_FILE
autocreate=$AUTO_CREATE
worldsize=$WORLD_SIZE
difficulty=$DIFFICULTY
port=$SERVER_PORT
maxplayers=$MAX_PLAYERS
language=$LANGUAGE
EOF

  if [ -n "$SERVER_PASSWORD" ]; then
    echo "password=$SERVER_PASSWORD" >> "$CONFIG_FILE"
  fi

  if [ -n "$SEED" ]; then
    echo "seed=$SEED" >> "$CONFIG_FILE"
  fi
fi

#######################################
# 启动 Terraria Server
#######################################

echo "Starting Terraria Server..."
echo "World file: $WORLD_FILE"
echo "Port: $SERVER_PORT"

exec "$SERVER_BIN" -config "$CONFIG_FILE"
