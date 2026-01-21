#!/usr/bin/env bash
set -e

# 创建日志目录并设置日志文件
mkdir -p /var/log
LOG_FILE="/var/log/entrypoint.log"
BACKUP_LOG="/var/log/backup.log"
RESTORE_LOG="/var/log/restore.log"

# 创建日志文件
touch "$LOG_FILE" "$BACKUP_LOG" "$RESTORE_LOG"

# 重定向所有输出到日志文件，同时保留到 stdout/stderr
exec > >(tee -a "$LOG_FILE") 2>&1

#######################################
# 设置 Mono 环境变量
#######################################
export MONO_CONFIG=/opt/terraria/monoconfig
export MONO_PATH=/opt/terraria

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
SAVEONQUIT=${SAVEONQUIT:-1}

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
# 检查 Terraria Server（应该在构建时已下载）
#######################################

if [ ! -f "$TERRARIA_BIN" ]; then
  echo "[ERROR] Terraria Server binary not found: $TERRARIA_BIN"
  echo "[ERROR] Please ensure the Docker image was built correctly with Terraria server files."
  exit 1
else
  echo "[INFO] Terraria Server binary found: $TERRARIA_BIN"
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
saveonquit=$SAVEONQUIT
EOF

  [ -n "$SERVER_PASSWORD" ] && echo "password=$SERVER_PASSWORD" >> "$CONFIG_FILE"
  [ -n "$SEED" ] && echo "seed=$SEED" >> "$CONFIG_FILE"
fi

#######################################
# screen 相关辅助
#######################################

SCREEN_SESSION=${SCREEN_SESSION:-terraria}

echo "[DEBUG] Environment variables:"
echo "  SCREEN_SESSION=$SCREEN_SESSION"
echo "  TERRARIA_BIN=$TERRARIA_BIN"
echo "  CONFIG_FILE=$CONFIG_FILE"

send_cmd() {
  local cmd="$1"
  # 在 screen 会话中发送命令（回车以 CRLF 形式）
  screen -S "$SCREEN_SESSION" -p 0 -X stuff "$cmd"$'\r' || {
    echo "[WARN] Failed to send command to screen session: $SCREEN_SESSION"
    return 1
  }
}

#######################################
# 优雅停服函数（通过 screen 注入命令）
#######################################

graceful_shutdown() {
  echo "[INFO] Received shutdown signal, saving world via screen..."

  # 检查 screen 会话是否存在
  if screen -ls | grep -q "\.${SCREEN_SESSION}[[:space:]]"; then
    # 先通知并保存
    send_cmd "say [Server] Shutting down, saving world..." || true
    send_cmd "save" || true
    sleep 5

    # 触发 on-quit 保存和退出
    send_cmd "exit" || true

    # 等待服务器退出，最多等 10 秒
    local timeout=10
    while [ $timeout -gt 0 ] && screen -ls | grep -q "\.${SCREEN_SESSION}[[:space:]]"; do
      echo "[INFO] Waiting for Terraria server to exit... (${timeout}s remaining)"
      sleep 1
      timeout=$((timeout - 1))
    done

    # 如果服务器还没退出，强制杀死 screen 会话
    if screen -ls | grep -q "\.${SCREEN_SESSION}[[:space:]]"; then
      echo "[WARN] Server didn't exit gracefully, killing screen session..."
      screen -S "$SCREEN_SESSION" -X quit || true
      sleep 2
    fi
  else
    echo "[WARN] Screen session '$SCREEN_SESSION' not found during shutdown"
  fi

  # 最后再执行一次备份（如果启用）
  if [ "$ENABLE_BACKUP" = "1" ]; then
    echo "[INFO] Creating final backup before shutdown..."
    # 设置环境变量表示这是关闭时的备份，避免显示警告
    SHUTDOWN_BACKUP=1 /usr/local/bin/backup.sh || true
  fi

  echo "[INFO] Graceful shutdown completed"
  exit 0
}

# 设置信号处理（在启动服务器之前设置，确保能捕获信号）
trap graceful_shutdown SIGTERM SIGINT

#######################################
# 启动服务器（screen 会话）
#######################################

echo "[INFO] Starting Terraria Server in screen session: $SCREEN_SESSION"

# 设置 Mono 环境变量（确保 Terraria 能正确运行）
export MONO_CONFIG=/opt/terraria/monoconfig
export MONO_PATH=/opt/terraria

# 启动 screen 会话（detached），但监控其状态
echo "[DEBUG] Executing: screen -DmS $SCREEN_SESSION $TERRARIA_BIN -config $CONFIG_FILE"

# 启动 screen 会话（异步，不等待）
screen -DmS "$SCREEN_SESSION" "$TERRARIA_BIN" -config "$CONFIG_FILE" &
SCREEN_PID=$!

# 短暂等待 screen 启动
sleep 1

# 检查 screen 进程是否还存在
if kill -0 $SCREEN_PID 2>/dev/null; then
  echo "[DEBUG] Screen command started successfully (PID: $SCREEN_PID)"
else
  echo "[ERROR] Screen command failed to start or exited immediately"
  wait $SCREEN_PID 2>/dev/null || true
  exit 1
fi

# 等待两秒确保 screen 会话启动或失败
echo "[DEBUG] Waiting for screen session to stabilize..."
sleep 2

# 检查 screen 会话是否成功创建
if screen -ls | grep -q "\.${SCREEN_SESSION}[[:space:]]"; then
  echo "[INFO] Terraria Server started in screen session: $SCREEN_SESSION"
else
  echo "[ERROR] Screen session '$SCREEN_SESSION' was not created or has already exited"
  echo "[DEBUG] Checking Terraria binary: $TERRARIA_BIN"
  ls -la "$TERRARIA_BIN" || echo "Binary not found"
  echo "[DEBUG] Checking config file: $CONFIG_FILE"
  ls -la "$CONFIG_FILE" || echo "Config not found"
  cat "$CONFIG_FILE" 2>/dev/null || echo "Cannot read config file"
  echo "[DEBUG] Checking Mono environment:"
  echo "MONO_CONFIG=$MONO_CONFIG"
  echo "MONO_PATH=$MONO_PATH"
  echo "[DEBUG] Checking Mono installation:"
  which mono || echo "mono not found in PATH"
  mono --version 2>/dev/null || echo "mono command failed"
  echo "[DEBUG] Current screen sessions:"
  screen -ls || echo "screen command failed"
  echo "[DEBUG] Trying to run Terraria directly for 5 seconds..."
  timeout 5s "$TERRARIA_BIN" -config "$CONFIG_FILE" || echo "Terraria direct run failed"
  exit 1
fi

#######################################
# 自动备份（cron，仅调用镜像内的 backup.sh）
#######################################

echo "[DEBUG] ENABLE_BACKUP=$ENABLE_BACKUP, BACKUP_INTERVAL=$BACKUP_INTERVAL"

if [ "$ENABLE_BACKUP" = "1" ]; then

  mkdir -p /var/log
  touch /var/log/cron.log /var/log/cron-backup.log /var/log/backup.log
  chmod 644 /var/log/cron*.log /var/log/backup.log

  # 创建包装脚本，确保 cron 任务能访问到环境变量
  # SERVER_PID 留空，让 backup.sh 自动查找（更可靠）
  cat > /usr/local/bin/backup-cron.sh <<EOF
#!/usr/bin/env bash
# Cron wrapper for backup.sh with environment variables
export WORLD_NAME="${WORLD_NAME}"
export WORLD_PATH="${WORLD_PATH}"
export BACKUP_DIR="${BACKUP_DIR}"
export BACKUP_RETAIN=${BACKUP_RETAIN}
export BACKUP_INTERVAL=${BACKUP_INTERVAL}
# SERVER_PID 留空，backup.sh 会自动查找 Terraria 进程
/usr/local/bin/backup.sh
EOF

  chmod +x /usr/local/bin/backup-cron.sh

  # 设置 cron 任务（使用包装脚本）
  CRON_LINE="*/${BACKUP_INTERVAL} * * * * root /usr/local/bin/backup-cron.sh"

  echo "$CRON_LINE" > /etc/cron.d/terraria-backup
  chmod 0644 /etc/cron.d/terraria-backup
  
  # 启动 cron 服务（后台运行）
  cron

  echo "[INFO] Automatic backup enabled: every ${BACKUP_INTERVAL} minutes"
fi

# 主进程监控 screen 会话状态，交由 trap 处理 SIGTERM
echo "[INFO] Container ready. Terraria server is running in screen session '$SCREEN_SESSION'"

# 监控 screen 会话，如果会话退出则退出容器
while screen -ls | grep -q "\.${SCREEN_SESSION}[[:space:]]"; do
  echo "[DEBUG] Screen session '$SCREEN_SESSION' is still running..."
  sleep 60
done

echo "[INFO] Screen session '$SCREEN_SESSION' has ended"
exit 0
