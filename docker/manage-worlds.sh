#!/usr/bin/env bash
set -e

#######################################
# 多世界管理脚本
# 用法: docker exec terraria-server /usr/local/bin/manage-worlds.sh <command> [options]
#######################################

# 配置目录
WORLDS_DIR=${WORLDS_DIR:-/worlds}
CONFIG_DIR=${CONFIG_DIR:-/config}
ACTIVE_WORLD_FILE="${CONFIG_DIR}/.active-world"
WORLDS_CONFIG_DIR="${CONFIG_DIR}/worlds"
MANAGE_LOG="/var/log/manage-worlds.log"

# 创建必要目录
mkdir -p "$WORLDS_CONFIG_DIR" "$(dirname "$ACTIVE_WORLD_FILE")" "$(dirname "$MANAGE_LOG")"

# 日志函数
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') [MANAGE] $*" | tee -a "$MANAGE_LOG"
}

error() {
  echo "ERROR: $*" >&2
  log "ERROR: $*"
  exit 1
}

# 列出所有世界
cmd_list() {
  log "Listing all worlds"

  echo "=== Worlds List ==="
  echo ""

  local active_world=""
  if [ -f "$ACTIVE_WORLD_FILE" ]; then
    active_world=$(cat "$ACTIVE_WORLD_FILE")
  fi

  # 检查是否有世界配置
  local world_configs=$(find "$WORLDS_CONFIG_DIR" -name "*.conf" -type f 2>/dev/null | sort)

  if [ -z "$world_configs" ]; then
    echo "No worlds configured."
    echo ""
    echo "Use 'create' command to create a new world."
    return 0
  fi

  for config_file in $world_configs; do
    local world_name=$(basename "$config_file" .conf)
    local indicator="   "

    if [ "$world_name" = "$active_world" ]; then
      indicator="-> "
    fi

    # 读取配置
    local world_file="${WORLDS_DIR}/${world_name}.wld"
    local world_exists="No"
    if [ -f "$world_file" ]; then
      world_exists="Yes"
      local world_size=$(du -h "$world_file" | cut -f1)
    else
      local world_size="N/A"
    fi

    local port=$(grep "^port=" "$config_file" 2>/dev/null | cut -d= -f2)
    local max_players=$(grep "^maxplayers=" "$config_file" 2>/dev/null | cut -d= -f2)
    local difficulty=$(grep "^difficulty=" "$config_file" 2>/dev/null | cut -d= -f2)
    local world_size_config=$(grep "^worldsize=" "$config_file" 2>/dev/null | cut -d= -f2)

    local difficulty_name="Classic"
    case "$difficulty" in
      0) difficulty_name="Classic" ;;
      1) difficulty_name="Expert" ;;
      2) difficulty_name="Master" ;;
      3) difficulty_name="Journey" ;;
      *) difficulty_name="Unknown" ;;
    esac

    local size_name="Medium"
    case "$world_size_config" in
      1) size_name="Small" ;;
      2) size_name="Medium" ;;
      3) size_name="Large" ;;
      *) size_name="Unknown" ;;
    esac

    printf "%s%-20s | Port: %-5s | Players: %-3s | %s | %s | %s\n" \
      "$indicator" "$world_name" "${port:-7777}" "${max_players:-16}" \
      "$difficulty_name" "$size_name" "$world_exists"
  done

  echo ""
  if [ -n "$active_world" ]; then
    echo "Active world: $active_world (marked with ->)"
  else
    echo "No active world set. Use 'switch' command to activate a world."
  fi
}

# 显示世界详情
cmd_show() {
  local world_name=$1

  if [ -z "$world_name" ]; then
    error "Usage: show <world_name>"
  fi

  local config_file="${WORLDS_CONFIG_DIR}/${world_name}.conf"

  if [ ! -f "$config_file" ]; then
    error "World '$world_name' not found."
  fi

  echo "=== World Details: $world_name ==="
  echo ""

  # 世界文件状态
  local world_file="${WORLDS_DIR}/${world_name}.wld"
  echo "World File: $world_file"
  if [ -f "$world_file" ]; then
    echo "  Status: Exists"
    echo "  Size: $(du -h "$world_file" | cut -f1)"
    echo "  Modified: $(stat -c %y "$world_file" 2>/dev/null || stat -f %Sm "$world_file" 2>/dev/null || echo 'N/A')"
  else
    echo "  Status: Not created yet"
  fi
  echo ""

  # 配置详情
  echo "Configuration:"
  while IFS='=' read -r key value; do
    [ -z "$key" ] && continue
    [[ "$key" =~ ^#.*$ ]] && continue

    local display_value="$value"
    case "$key" in
      password)
        if [ -n "$value" ]; then
          display_value="***"
        else
          display_value="(none)"
        fi
        ;;
      seed)
        if [ -z "$value" ]; then
          display_value="(random)"
        fi
        ;;
      worldsize)
        case "$value" in
          1) display_value="1 (Small)" ;;
          2) display_value="2 (Medium)" ;;
          3) display_value="3 (Large)" ;;
          *) display_value="$value (Unknown)" ;;
        esac
        ;;
      difficulty)
        case "$value" in
          0) display_value="0 (Classic)" ;;
          1) display_value="1 (Expert)" ;;
          2) display_value="2 (Master)" ;;
          3) display_value="3 (Journey)" ;;
          *) display_value="$value (Unknown)" ;;
        esac
        ;;
    esac
    echo "  $key: $display_value"
  done < "$config_file"
}

# 创建新世界
cmd_create() {
  local world_name=$1
  shift

  if [ -z "$world_name" ]; then
    error "Usage: create <world_name> [options]"
  fi

  # 验证世界名称
  if [[ ! "$world_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    error "Invalid world name. Only letters, numbers, hyphens and underscores are allowed."
  fi

  local config_file="${WORLDS_CONFIG_DIR}/${world_name}.conf"
  local world_file="${WORLDS_DIR}/${world_name}.wld"

  if [ -f "$config_file" ]; then
    error "World '$world_name' already exists."
  fi

  # 解析选项
  local port=7777
  local max_players=16
  local password=""
  local language="en-US"
  local autosave=1
  local world_size=2
  local difficulty=0
  local seed=""
  local auto_create=1

  while [ $# -gt 0 ]; do
    case "$1" in
      --port)
        port="$2"
        shift 2
        ;;
      --max-players)
        max_players="$2"
        shift 2
        ;;
      --password)
        password="$2"
        shift 2
        ;;
      --language)
        language="$2"
        shift 2
        ;;
      --world-size)
        world_size="$2"
        shift 2
        ;;
      --difficulty)
        difficulty="$2"
        shift 2
        ;;
      --seed)
        seed="$2"
        shift 2
        ;;
      *)
        error "Unknown option: $1"
        ;;
    esac
  done

  # 验证选项
  if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
    error "Invalid port number. Must be between 1 and 65535."
  fi

  if ! [[ "$max_players" =~ ^[0-9]+$ ]] || [ "$max_players" -lt 1 ] || [ "$max_players" -gt 255 ]; then
    error "Invalid max players. Must be between 1 and 255."
  fi

  if ! [[ "$world_size" =~ ^[1-3]$ ]]; then
    error "Invalid world size. Must be 1 (Small), 2 (Medium), or 3 (Large)."
  fi

  if ! [[ "$difficulty" =~ ^[0-3]$ ]]; then
    error "Invalid difficulty. Must be 0 (Classic), 1 (Expert), 2 (Master), or 3 (Journey)."
  fi

  # 创建配置文件
  cat > "$config_file" <<EOF
# World configuration for: $world_name
world=${world_file}
autocreate=${auto_create}
worldsize=${world_size}
difficulty=${difficulty}
port=${port}
maxplayers=${max_players}
language=${language}
autosave=${autosave}
EOF

  [ -n "$password" ] && echo "password=${password}" >> "$config_file"
  [ -n "$seed" ] && echo "seed=${seed}" >> "$config_file"

  log "Created world: $world_name"
  echo "World '$world_name' created successfully."
  echo ""
  echo "Configuration:"
  echo "  Port: $port"
  echo "  Max Players: $max_players"
  echo "  World Size: $world_size"
  echo "  Difficulty: $difficulty"
  [ -n "$seed" ] && echo "  Seed: $seed"
  [ -n "$password" ] && echo "  Password: ***"
  echo ""
  echo "Use 'switch $world_name' to activate this world, then restart the server."
}

# 切换到指定世界
cmd_switch() {
  local world_name=$1

  if [ -z "$world_name" ]; then
    error "Usage: switch <world_name>"
  fi

  local config_file="${WORLDS_CONFIG_DIR}/${world_name}.conf"

  if [ ! -f "$config_file" ]; then
    error "World '$world_name' not found."
  fi

  echo "$world_name" > "$ACTIVE_WORLD_FILE"

  log "Switched active world to: $world_name"
  echo "Active world set to: $world_name"
  echo ""
  echo "IMPORTANT: You must restart the server for the changes to take effect."
  echo "  docker compose restart"
}

# 删除世界
cmd_delete() {
  local world_name=$1

  if [ -z "$world_name" ]; then
    error "Usage: delete <world_name>"
  fi

  local config_file="${WORLDS_CONFIG_DIR}/${world_name}.conf"
  local world_file="${WORLDS_DIR}/${world_name}.wld"

  if [ ! -f "$config_file" ]; then
    error "World '$world_name' not found."
  fi

  # 检查是否是当前激活的世界
  local active_world=""
  if [ -f "$ACTIVE_WORLD_FILE" ]; then
    active_world=$(cat "$ACTIVE_WORLD_FILE")
  fi

  if [ "$world_name" = "$active_world" ]; then
    error "Cannot delete the active world. Switch to another world first."
  fi

  # 确认删除
  echo -n "Are you sure you want to delete world '$world_name'? This cannot be undone. (yes/no): "
  read -r confirm

  if [ "$confirm" != "yes" ]; then
    echo "Deletion cancelled."
    return 0
  fi

  # 删除配置文件
  rm -f "$config_file"
  log "Deleted config: $config_file"

  # 询问是否删除世界文件
  if [ -f "$world_file" ]; then
    echo -n "Delete the world file too? (yes/no): "
    read -r delete_file
    if [ "$delete_file" = "yes" ]; then
      rm -f "$world_file" "${world_file}.bak" 2>/dev/null || true
      log "Deleted world file: $world_file"
      echo "World file deleted."
    else
      echo "World file preserved."
    fi
  fi

  echo "World '$world_name' deleted successfully."
}

# 显示帮助
cmd_help() {
  echo "Multi-World Management Script"
  echo ""
  echo "Usage: manage-worlds.sh <command> [options]"
  echo ""
  echo "Commands:"
  echo "  list                      List all worlds"
  echo "  show <world_name>         Show detailed world information"
  echo "  create <world_name>       Create a new world"
  echo "  switch <world_name>       Switch to a world (requires restart)"
  echo "  delete <world_name>       Delete a world"
  echo "  help                      Show this help message"
  echo ""
  echo "Create options:"
  echo "  --port <port>             Server port (default: 7777)"
  echo "  --max-players <count>     Maximum players (default: 16)"
  echo "  --password <password>     Server password (default: none)"
  echo "  --language <lang>         Language (default: en-US)"
  echo "  --world-size <size>       World size: 1=Small, 2=Medium, 3=Large (default: 2)"
  echo "  --difficulty <diff>       Difficulty: 0=Classic, 1=Expert, 2=Master, 3=Journey (default: 0)"
  echo "  --seed <seed>             World seed (default: random)"
  echo ""
  echo "Examples:"
  echo "  manage-worlds.sh list"
  echo "  manage-worlds.sh create survival --port 7777 --difficulty 1"
  echo "  manage-worlds.sh switch survival"
  echo "  manage-worlds.sh show survival"
  echo "  manage-worlds.sh delete old-world"
}

# 主函数
main() {
  local command=$1
  shift || true

  case "$command" in
    list)
      cmd_list
      ;;
    show)
      cmd_show "$@"
      ;;
    create)
      cmd_create "$@"
      ;;
    switch)
      cmd_switch "$@"
      ;;
    delete)
      cmd_delete "$@"
      ;;
    help|--help|-h)
      cmd_help
      ;;
    *)
      echo "Unknown command: $command"
      echo ""
      cmd_help
      exit 1
      ;;
  esac
}

main "$@"
