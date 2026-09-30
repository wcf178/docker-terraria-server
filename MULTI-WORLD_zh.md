# 多世界管理功能

此功能允许您管理多个 Terraria 世界，并在它们之间切换。

---

## 概述

多世界管理功能提供以下特性：

- **多个世界配置**：每个世界有独立的配置（端口、密码、难度、玩家数等）
- **切换运行模式**：同一时间只运行一个世界，通过命令切换
- **独立世界文件**：每个世界有独立的世界文件
- **独立备份**：每个世界有独立的备份文件

---

## 启用多世界模式

在 `.env` 文件中设置：

```env
MULTI_WORLD_MODE=1
```

---

## 管理命令

推荐使用网页管理后台创建、切换和备份世界。启动后访问 `http://localhost:8080`；请先在 `.env` 中设置 `DASHBOARD_PASSWORD`。命令行管理方式仍可使用：

```bash
docker compose exec terraria /usr/local/bin/manage-worlds.sh <command> [options]
```

### 可用命令

| 命令 | 描述 |
| :--- | :--- |
| `list` | 列出所有世界 |
| `show <name>` | 显示世界详细信息 |
| `create <name>` | 创建新世界 |
| `switch <name>` | 切换到指定世界 |
| `delete <name>` | 删除世界 |
| `help` | 显示帮助信息 |

---

## 使用示例

### 1. 列出所有世界

```bash
docker compose exec terraria /usr/local/bin/manage-worlds.sh list
```

输出示例：
```
=== Worlds List ===

    survival          | Port: 7777  | Players: 16  | Classic | Medium | Yes
->  creative          | Port: 7778  | Players: 8   | Journey | Small  | Yes
    hardcore          | Port: 7779  | Players: 4   | Expert  | Large  | No

Active world: creative (marked with ->)
```

### 2. 创建新世界

```bash
docker compose exec terraria /usr/local/bin/manage-worlds.sh create survival --port 7777 --max-players 16 --difficulty 1
```

创建参数：

| 参数 | 描述 | 默认值 |
| :--- | :--- | :--- |
| `--port` | 服务器端口 | 7777 |
| `--max-players` | 最大玩家数 | 16 |
| `--password` | 服务器密码 | 无 |
| `--language` | 语言 | en-US |
| `--world-size` | 世界大小 (1=小, 2=中, 3=大) | 2 |
| `--difficulty` | 难度 (0=经典, 1=专家, 2=大师, 3=旅行) | 0 |
| `--seed` | 世界种子 | 随机 |

### 3. 切换世界

```bash
docker compose exec terraria /usr/local/bin/manage-worlds.sh switch survival
```

切换后需要重启服务器：

```bash
docker compose restart
```

### 4. 显示世界详情

```bash
docker compose exec terraria /usr/local/bin/manage-worlds.sh show survival
```

### 5. 删除世界

```bash
docker compose exec terraria /usr/local/bin/manage-worlds.sh delete old-world
```

注意：无法删除当前激活的世界，需要先切换到其他世界。

---

## 端口映射配置

多世界模式下，每个世界使用独立的端口。需要相应配置 `docker-compose.yml` 中的端口映射。

### 方式一：映射所有可能用到的端口

```yaml
ports:
  - "7777-7785:7777-7785"
```

### 方式二：为每个世界单独映射

```yaml
ports:
  - "7777:7777"  # world1
  - "7778:7778"  # world2
  - "7779:7779"  # world3
```

---

## 数据结构

多世界模式下的目录结构：

```
./config/
├── .active-world          # 当前激活的世界名称
├── server.conf            # 单世界模式配置（多世界模式下自动生成）
└── worlds/                # 多世界配置目录
    ├── survival.conf      # 世界配置文件
    ├── creative.conf
    └── hardcore.conf

./worlds/
├── survival.wld           # 世界文件
├── survival.wld.bak
├── creative.wld
└── hardcore.wld

./backups/
├── survival-20250125-120000.tar.gz    # 世界备份
├── creative-20250125-120000.tar.gz
└── ...
```

---

## 与单世界模式的区别

| 特性 | 单世界模式 | 多世界模式 |
| :--- | :--- | :--- |
| 环境变量配置 | 使用 `.env` 中的变量 | 使用每个世界的独立配置文件 |
| 配置文件位置 | `config/server.conf` | `config/worlds/<name>.conf` |
| 启动参数 | 使用 `.env` 中的 WORLD_NAME | 使用 `.active-world` 指定的世界 |
| 世界切换 | 需要修改 `.env` 并重启 | 使用 `switch` 命令 |

---

## 常见问题

### Q: 切换世界后服务器没有启动？

A: 确保已重启服务器，并且 `docker-compose.yml` 中的端口映射包含新世界的端口。

### Q: 如何查看当前运行的是哪个世界？

A: 使用 `docker compose exec terraria /usr/local/bin/manage-worlds.sh list` 命令，当前激活的世界会有 `->` 标记。

### Q: 能否同时运行多个世界？

A: 当前版本支持切换运行模式，同一时间只运行一个世界。如需同时运行多个世界，可以运行多个容器。

---

## 迁移现有世界到多世界模式

如果您已经有一个世界，可以按以下步骤迁移到多世界模式：

1. 停止服务器：
   ```bash
   docker compose down
   ```

2. 启用多世界模式，编辑 `.env`：
   ```env
   MULTI_WORLD_MODE=1
   ```

3. 创建对应的世界配置（使用与原世界相同的设置）：
   ```bash
   # 创建与世界文件同名的配置
   docker compose up -d
   docker compose exec terraria /usr/local/bin/manage-worlds.sh create world --port 7777 ...
   docker compose exec terraria /usr/local/bin/manage-worlds.sh switch world
   ```

4. 重启服务器：
   ```bash
   docker compose restart
   ```
