# Docker Terraria 服务器

**语言选择 :** 中文 | [English](README.md)

一个使用 Docker 容器化的 **原版 Terraria 服务器** 解决方案，允许您在 Linux（例如 CentOS）上使用 **Docker Compose** 快速部署和运行一个持久化的 Terraria 服务器。所有核心配置都通过环境变量管理，支持自动世界持久化、自动保存和优雅关闭。

> **状态**: MVP / v0.1.0
> 重点：稳定、可复现且对新手友好的 Terraria 服务器部署。

---

## ✨ 特性

*   原版 Terraria 服务器（无模组）
*   使用 `docker compose up -d` 一键启动
*   通过 `.env` 文件驱动配置 → 自动生成 `server.conf`
*   通过 Docker 卷实现持久化世界数据
*   默认启用自动保存
*   优雅关闭（容器停止时世界会被保存）
*   适合长期运行的服务器

---

## 📦 要求

*   Linux 服务器（推荐 CentOS / Ubuntu / Debian）
*   Docker >= 20.x
*   Docker Compose v2 (`docker compose`)

可选但建议：
*   至少 **1 GB 内存**
*   开放端口 `7777`（或自定义端口）

---

## 🚀 快速开始

### 1. 克隆仓库

```bash
git clone https://github.com/wcf178/docker-terraria-server.git
cd docker-terraria-server
```

### 2. 创建 `.env` 文件

```bash
cp .env.example .env
```

根据需要编辑 `.env`（参见下方配置部分）。

### 3. 启动服务器

```bash
docker compose up -d
```

### 4. 加入游戏

*   IP: **您的服务器 IP**
*   端口: **7777** （默认）
*   密码: *（如果已配置）*

---

## ⚙️ 配置

所有配置都通过环境变量控制，并在 **首次启动时** 写入 `server.conf`。

### 核心环境变量

| 变量              | 默认值          | 描述                           |
| ----------------- | --------------- | ------------------------------ |
| `WORLD_NAME`      | `world`         | 世界文件名（不带 `.wld` 后缀） |
| `WORLD_PATH`      | `/worlds`       | 世界存储目录                   |
| `AUTO_CREATE`     | `1`             | 如果缺失则自动创建世界         |
| `WORLD_SIZE`      | `2`             | 世界大小 (1=小, 2=中, 3=大)    |
| `DIFFICULTY`      | `0`             | 难度 (0=经典, 1=专家, 2=大师)  |
| `SEED`            | *(空)*          | 世界种子                       |
| `SERVER_PORT`     | `7777`          | 服务器端口                     |
| `MAX_PLAYERS`     | `16`            | 最大玩家数                     |
| `SERVER_PASSWORD` | *(空)*          | 服务器密码                     |
| `LANGUAGE`        | `en-US`         | 服务器语言                     |
| `AUTOSAVE`        | `1`             | 启用自动保存（推荐）           |
| `TZ`              | `Asia/Shanghai` | 容器时区                       |

> ⚠️ 一旦 `server.conf` 生成，更改 `.env` 将 **不会覆盖** 它。您必须手动编辑 `server.conf` 或删除它并重启容器。

---

## 💾 数据持久化

### 卷

以下目录 **必须持久化**：

*   `/worlds` – Terraria 世界文件
*   `/config` – `server.conf`

示例（docker-compose.yml）:
```yaml
volumes:
  - ./worlds:/worlds
  - ./config:/config
```

如果不使用卷，世界数据在容器重启时 **将会丢失**。

---

## 💡 自动保存与优雅关闭

### 自动保存

*   默认启用：`autosave=1`
*   世界每 **5 分钟** 自动保存一次

### 优雅关闭（重要）

当停止容器时：
```bash
docker compose down
```

服务器将：
1.  接收 `SIGTERM` 信号
2.  执行 `save` 命令
3.  将世界数据刷新到磁盘
4.  安全退出

### ❌ 请勿使用

```bash
docker kill <容器名或ID>
```

这可能导致最近的游戏进度回滚。

---

## 🛠️ 管理服务器

### 查看日志

```bash
docker compose logs -f
```

### 查看 screen 会话（可选）

容器内使用 `screen` 管理 Terraria 进程：

```bash
docker compose exec terraria bash
screen -ls          # 列出会话（默认名：terraria）
screen -r terraria  # 附加到会话（只读/调试用）
```

### 重启服务器

```bash
docker compose restart
```

### 进入容器

```bash
docker compose exec terraria bash
```

### 手动触发备份

```bash
docker compose exec terraria backup.sh
```

该命令会通过 `screen` 向服务器发送 `save` 命令，并在 `/backups` 目录生成一个 `world-时间戳.tar.gz` 备份包。

---

## 🧯 故障排除

### 世界更改未保存

检查清单：
*   [ ] `server.conf` 中 `autosave=1`
*   [ ] `/worlds` 已挂载为卷
*   [ ] 通过 `docker compose down` 停止容器

### 端口无法访问

*   检查防火墙规则
*   确保 `SERVER_PORT` 已暴露
*   确认云服务商的安全组设置

### server.conf 未更新

*   `server.conf` 只在 **首次启动时** 生成
*   删除 `/config/server.conf` 并重启容器以重新生成

---

## 🗺️ 路线图

*   [ ] 自动服务器版本下载
*   [ ] 多世界配置文件
*   [ ] 定时世界备份
*   [ ] TShock / tModLoader 支持（可选）
*   [ ] 基于 Web 的管理面板（可选）

---

## 🤝 贡献

欢迎贡献。

1.  复刻仓库
2.  创建特性分支
3.  提交更改
4.  发起拉取请求

---

## 📄 许可证

MIT 许可证

---

## ❤️ 致谢

*   Terraria by Re-Logic
*   Docker 社区

---

## ⚠️ 免责声明

此项目 **与 Re-Logic 无关，也未受其认可**。Terraria 是其各自所有者的注册商标。

