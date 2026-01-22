#!/usr/bin/env bash
set -e

# 创建日志目录并设置日志文件
mkdir -p /var/log
LOG_FILE="/var/log/entrypoint.log"
BACKUP_LOG="/var/log/backup.log"
RESTORE_LOG="/var/log/restore.log"

# 创建日志文件
touch "$LOG_FILE" "$BACKUP_LOG" "$RESTORE_LOG"

# 日志函数
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') [ENTRYPOINT] $*" | tee -a "$LOG_FILE"
}

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
  log "ERROR: Terraria Server binary not found: $TERRARIA_BIN"
  log "ERROR: Please ensure the Docker image was built correctly with Terraria server files."
  exit 1
else
  log "INFO: Terraria Server binary found: $TERRARIA_BIN"
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

log "DEBUG: Environment variables:"
log "  SCREEN_SESSION=$SCREEN_SESSION"
log "  TERRARIA_BIN=$TERRARIA_BIN"
log "  CONFIG_FILE=$CONFIG_FILE"

send_cmd() {
  local cmd="$1"
  log "DEBUG: Sending command to screen: $cmd"
  # 在 screen 会话中发送命令（回车以 CRLF 形式）
  if screen -S "$SCREEN_SESSION" -p 0 -X stuff "$cmd"$'\r'; then
    log "DEBUG: Command sent successfully: $cmd"
    return 0
  else
    log "WARN: Failed to send command to screen session: $SCREEN_SESSION"
    return 1
  fi
}

#######################################
# 优雅停服函数（通过 screen 注入命令）
#######################################

graceful_shutdown() {
  log "INFO: Received shutdown signal, saving world via screen..."

  # 检查 screen 会话是否存在
  log "DEBUG: Checking for screen session: $SCREEN_SESSION"
  if screen -ls | grep -q "\.${SCREEN_SESSION}[[:space:]]"; then
    log "DEBUG: Screen session found, proceeding with graceful shutdown"

    # 先通知并保存
    log "DEBUG: Sending shutdown notification..."
    if ! send_cmd "say [Server] Shutting down, saving world..."; then
      log "ERROR: Failed to send shutdown notification"
    fi

    log "DEBUG: Sending save command..."
    if ! send_cmd "save"; then
      log "ERROR: Failed to send save command"
    fi

    log "DEBUG: Waiting 5 seconds for save to complete..."
    sleep 5

    # 触发 on-quit 保存和退出
    log "DEBUG: Sending exit command..."
    if ! send_cmd "exit"; then
      log "ERROR: Failed to send exit command"
    fi

    # 等待服务器退出，最多等 10 秒
    log "DEBUG: Waiting for server to exit..."
    local timeout=10
    while [ $timeout -gt 0 ] && screen -ls | grep -q "\.${SCREEN_SESSION}[[:space:]]"; do
      log "INFO: Waiting for Terraria server to exit... (${timeout}s remaining)"
      sleep 1
      timeout=$((timeout - 1))
    done

    # 检查是否成功退出
    if screen -ls | grep -q "\.${SCREEN_SESSION}[[:space:]]"; then
      log "WARN: Server didn't exit gracefully, force killing screen session..."
      screen -S "$SCREEN_SESSION" -X quit || log "ERROR: Failed to kill screen session"
      sleep 2
    else
      log "DEBUG: Server exited successfully"
    fi
  else
    log "WARN: Screen session '$SCREEN_SESSION' not found during shutdown"
  fi

  # 最后再执行一次备份（如果启用）
  if [ "$ENABLE_BACKUP" = "1" ]; then
    log "INFO: Creating final backup before shutdown..."
    # 设置环境变量表示这是关闭时的备份，避免显示警告
    SHUTDOWN_BACKUP=1 /usr/local/bin/backup.sh || log "ERROR: Backup failed during shutdown"
  fi

  log "INFO: Graceful shutdown completed"
  exit 0
}

# 设置信号处理（在启动服务器之前设置，确保能捕获信号）
trap graceful_shutdown SIGTERM SIGINT

#######################################
# 启动服务器（screen 会话）
#######################################

log "INFO: Starting Terraria Server in screen session: $SCREEN_SESSION"

# 设置 Mono 环境变量（确保 Terraria 能正确运行）
export MONO_CONFIG=/opt/terraria/monoconfig
export MONO_PATH=/opt/terraria

# 启动 screen 会话（detached），但监控其状态
log "DEBUG: Executing: screen -DmS $SCREEN_SESSION $TERRARIA_BIN -config $CONFIG_FILE"

# 启动 screen 会话（异步，不等待）
screen -DmS "$SCREEN_SESSION" "$TERRARIA_BIN" -config "$CONFIG_FILE" &
SCREEN_PID=$!

# 短暂等待 screen 启动
sleep 1

# 检查 screen 进程是否还存在
if kill -0 $SCREEN_PID 2>/dev/null; then
  log "DEBUG: Screen command started successfully (PID: $SCREEN_PID)"
else
  log "ERROR: Screen command failed to start or exited immediately"
  wait $SCREEN_PID 2>/dev/null || true
  exit 1
fi

# 等待两秒确保 screen 会话启动或失败
log "DEBUG: Waiting for screen session to stabilize..."
sleep 2

# 检查 screen 会话是否成功创建
if screen -ls | grep -q "\.${SCREEN_SESSION}[[:space:]]"; then
  log "INFO: Terraria Server started in screen session: $SCREEN_SESSION"
else
  log "ERROR: Screen session '$SCREEN_SESSION' was not created or has already exited"
  log "DEBUG: Checking Terraria binary: $TERRARIA_BIN"
  ls -la "$TERRARIA_BIN" || log "Binary not found"
  log "DEBUG: Checking config file: $CONFIG_FILE"
  ls -la "$CONFIG_FILE" || log "Config not found"
  cat "$CONFIG_FILE" 2>/dev/null || log "Cannot read config file"
  log "DEBUG: Checking Mono environment:"
  log "MONO_CONFIG=$MONO_CONFIG"
  log "MONO_PATH=$MONO_PATH"
  log "DEBUG: Checking Mono installation:"
  which mono || log "mono not found in PATH"
  mono --version 2>/dev/null || log "mono command failed"
  log "DEBUG: Current screen sessions:"
  screen -ls || log "screen command failed"
  log "DEBUG: Trying to run Terraria directly for 5 seconds..."
  timeout 5s "$TERRARIA_BIN" -config "$CONFIG_FILE" || log "Terraria direct run failed"
  exit 1
fi

#######################################
# 自动备份（cron，仅调用镜像内的 backup.sh）
#######################################

log "DEBUG: ENABLE_BACKUP=$ENABLE_BACKUP, BACKUP_INTERVAL=$BACKUP_INTERVAL"

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

  log "INFO: Automatic backup enabled: every ${BACKUP_INTERVAL} minutes"
fi

# 主进程监控 screen 会话状态，交由 trap 处理 SIGTERM
log "INFO: Container ready. Terraria server is running in screen session '$SCREEN_SESSION'"

# 获取 Terraria 服务器进程 PID（即使在 screen 中运行，pgrep 也能找到）
# 多次尝试，因为进程可能需要一点时间启动
log "DEBUG: Looking for Terraria server process..."
log "DEBUG: Screen process PID is: $SCREEN_PID"

for i in {1..5}; do
  # 查找所有匹配的进程
  ALL_PIDS=$(pgrep -f 'TerrariaServer.bin.x86_64' || true)
  if [ -n "$ALL_PIDS" ]; then
    log "DEBUG: Found matching PIDs: $ALL_PIDS"
    
    # 显示所有匹配进程的详细信息
    log "DEBUG: Process details for all matches:"
    echo "$ALL_PIDS" | while read pid; do
      if [ -n "$pid" ]; then
        PROC_INFO=$(ps -p $pid -o pid,ppid,comm,args --no-headers 2>/dev/null || echo "Unable to get info for PID $pid")
        log "DEBUG:   PID $pid: $PROC_INFO"
      fi
    done
    
    # 选择正确的进程：找到 PPID 等于 SCREEN_PID 的进程（即 screen 的子进程）
    # 这样可以准确找到 Terraria 服务器进程，而不是 screen 进程本身
    TERRARIA_PID=$(ps -o pid,ppid --no-headers -p $ALL_PIDS 2>/dev/null | awk -v screen_pid="$SCREEN_PID" '$2 == screen_pid {print $1}' | head -n 1 || true)
    
    if [ -n "$TERRARIA_PID" ]; then
      log "DEBUG: Selected Terraria server PID: $TERRARIA_PID (child of screen PID: $SCREEN_PID)"
      break
    fi
  fi
  
  log "DEBUG: Attempt $i/5: Terraria process not found yet, waiting..."
  sleep 1
done

if [ -n "$TERRARIA_PID" ]; then
  log "INFO: Found Terraria server process (PID: $TERRARIA_PID)"
  PROC_DETAILS=$(ps -p $TERRARIA_PID -o pid,ppid,comm,args --no-headers 2>/dev/null || echo 'Unable to get process details')
  log "INFO: Process details: $PROC_DETAILS"
  
  # 使用 tail --pid 等待进程结束
  # tail 会在 TERRARIA_PID 退出后自动退出，比 while 循环更高效
  # 这种方法不占用 CPU，并且能被 SIGTERM 中断
  tail -f /dev/null --pid="$TERRARIA_PID" &
  TAIL_PID=$!
  
  # 等待 tail 进程（即等待 Terraria 进程结束）
  # 如果收到 SIGTERM，wait 会被中断，trap 会处理优雅关闭
  wait $TAIL_PID 2>/dev/null || {
    EXIT_CODE=$?
    log "WARN: Wait command exited with code $EXIT_CODE"
  }
else
  log "ERROR: Terraria server process not found after 5 attempts"
  log "DEBUG: All running processes containing 'terraria':"
  ps aux | grep -i terraria || true
  log "DEBUG: Screen sessions:"
  screen -ls || true
  exit 1
fi

log "INFO: Terraria server has ended"
exit 0
