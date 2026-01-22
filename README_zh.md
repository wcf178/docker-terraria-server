# Docker Terraria 服务器

**语言选择 :** 中文 | [English](README.md)

一个使用 Docker 容器化的 **原版 Terraria 服务器** 解决方案，允许您在 Linux 上使用 **Docker Compose** 快速部署和运行持久化的 Terraria 服务器。所有核心配置都通过环境变量管理，支持自动世界持久化、自动保存、定时备份和优雅关闭。

> **状态**: 稳定版 / v0.1.0
> 重点：稳定、可复现且对新手友好的 Terraria 服务器部署。

---

## ✨ 特性

*   **原版 Terraria 服务器**：纯净体验，无模组。
*   **一键启动**：使用 `docker compose up -d` 立即部署。
*   **环境变量驱动**：通过 `.env` 文件进行配置，自动生成 `server.conf`。
*   **数据持久化**：通过 Docker 卷持久化世界数据、配置和日志。
*   **定时备份**：内置自动世界备份功能，支持自定义备份间隔和保留数量。
*   **优雅关闭**：容器停止时（SIGTERM）自动保存世界并执行最终备份。
*   **健康检查**：内置健康监测，确保服务器响应正常。
*   **日志管理**：集中管理启动、备份和恢复日志。

---

## 📦 要求

*   **操作系统**：Linux (Ubuntu, Debian, CentOS 等)
*   **Docker**：>= 20.x
*   **Docker Compose**：v2 (`docker compose`)

**推荐配置：**
*   至少 **1 GB 内存**
*   开放端口 **7777** (TCP/UDP)

---

## 🚀 快速开始

### 1. 克隆仓库

```bash
git clone https://github.com/wcf178/docker-terraria-server.git
cd docker-terraria-server
```

### 2. 配置环境

```bash
cp .env.example .env
```

编辑 `.env` 文件，设置您的世界名称、密码和其他偏好。

### 3. 启动服务器

```bash
docker compose up -d
```

### 4. 加入游戏

*   **IP**: 您的服务器公网 IP
*   **端口**: `7777` (默认)
*   **密码**: (在 `.env` 中设置的密码)

---

## ⚙️ 配置

所有配置均通过 `.env` 文件中的环境变量管理。这些变量在首次运行时用于生成 `server.conf` 文件。

### 核心变量

| 变量 | 默认值 | 描述 |
| :--- | :--- | :--- |
| `WORLD_NAME` | `world` | 世界文件名（不带 `.wld` 后缀） |
| `AUTO_CREATE` | `1` | 若未找到世界则自动创建 (1=是, 0=否) |
| `WORLD_SIZE` | `2` | 世界大小 (1=小, 2=中, 3=大) |
| `DIFFICULTY` | `0` | 难度 (0=经典, 1=专家, 2=大师, 3=旅行) |
| `SEED` | | 世界种子（可选） |
| `SERVER_PORT` | `7777` | 服务器端口 |
| `MAX_PLAYERS` | `16` | 最大玩家数 |
| `SERVER_PASSWORD`| | 服务器密码（可选） |
| `LANGUAGE` | `en-US` | 服务器语言 |
| `AUTOSAVE` | `1` | 启用游戏内自动保存 |
| `TZ` | `Asia/Shanghai`| 容器时区 |

### 备份变量

| 变量 | 默认值 | 描述 |
| :--- | :--- | :--- |
| `ENABLE_BACKUP` | `1` | 启用定时备份 |
| `BACKUP_INTERVAL`| `30` | 备份频率（分钟） |
| `BACKUP_RETAIN` | `10` | 保留的备份文件数量 |

> ⚠️ **注意**：`server.conf` 仅在 **首次启动时** 生成。如果您之后更改了 `.env`，必须删除 `config/server.conf` 并重启容器以重新生成，或者手动编辑 `server.conf`。

---

## 💾 备份与恢复

### 自动备份
备份由容器内的 cron 任务触发，以 `.tar.gz` 格式存储在 `./backups` 目录中。

### 手动备份
您可以随时手动触发备份：
```bash
docker compose exec terraria backup.sh
```

### 恢复备份
1.  **停止服务器**：`docker compose down`
2.  **查看备份列表**：`ls ./backups`
3.  **执行恢复**：
    ```bash
    docker compose run --rm --entrypoint restore.sh terraria <备份文件名.tar.gz>
    ```
4.  **重新启动**：`docker compose up -d`

---

## 🛠️ 管理服务器

### 查看日志
*   **综合日志**：`docker compose logs -f`
*   **启动日志**：`tail -f logs/entrypoint.log`
*   **备份日志**：`tail -f logs/backup.log`

### 交互式控制台
服务器运行在 `screen` 会话中。您可以附加到会话进行调试或手动输入命令：
```bash
docker compose exec terraria screen -r terraria
```
*(按 `Ctrl+A` 然后按 `D` 退出附加状态)*

### 重启服务器
```bash
docker compose restart
```

---

## 💡 优雅关闭
当您运行 `docker compose down` 或 `docker stop` 时，容器会发送 `SIGTERM` 信号。脚本会捕获此信号并执行以下操作：
1.  在游戏内通知玩家。
2.  执行 `save` 命令保存世界。
3.  执行一次最终备份。
4.  安全退出服务器进程。

**请勿** 使用 `docker kill`，否则可能导致数据丢失。

---

## 📄 许可证
MIT 许可证。详见 [LICENSE](LICENSE) 文件。

---

## ❤️ 致谢
*   [Terraria](https://terraria.org/) by Re-Logic.
*   此项目与 Re-Logic 无关，也未受其认可。
