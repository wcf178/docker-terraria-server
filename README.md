# Docker Terraria Server

**Language:** [中文](README_zh.md) | English

A Dockerized **Vanilla Terraria Server** solution that allows you to quickly deploy and run a persistent Terraria server on Linux using **Docker Compose**. All core configurations are managed via environment variables, with automatic world persistence, autosave, scheduled backups, and graceful shutdown support.

> **Status**: Stable / v0.1.0
> Focus: Stable, reproducible, and beginner-friendly Terraria server deployment.

---

## ✨ Features

* **Vanilla Terraria Server**: Pure experience without mods.
* **One-command Startup**: Deploy instantly with `docker compose up -d`.
* **Environment Driven**: Configuration via `.env` file, automatically generating `server.conf`.
* **Data Persistence**: Persistent world data and logs via Docker volumes.
* **Scheduled Backups**: Automatic world backups with configurable intervals and retention.
* **Graceful Shutdown**: Automatically saves the world when the container stops (SIGTERM).
* **Health Checks**: Built-in health monitoring to ensure the server is responsive.
* **Log Management**: Centralized logs for the entrypoint, backups, and restores.

---

## 📦 Requirements

* **OS**: Linux (Ubuntu, Debian, CentOS, etc.)
* **Docker**: >= 20.x
* **Docker Compose**: v2 (`docker compose`)

**Recommended Hardware:**
* At least **1 GB RAM**
* Open port **7777** (TCP/UDP)

---

## 🚀 Quick Start

### 1. Clone the repository

```bash
git clone https://github.com/wcf178/docker-terraria-server.git
cd docker-terraria-server
```

### 2. Configure Environment

```bash
cp .env.example .env
```

Edit `.env` to set your world name, password, and other preferences.

### 3. Start the Server

```bash
docker compose up -d
```

### 4. Join the Game

* **IP**: Your server's public IP
* **Port**: `7777` (default)
* **Password**: (As set in `.env`)

---

## ⚙️ Configuration

Configurations are managed via environment variables in the `.env` file. These are used to generate the `server.conf` file on the first run.

### Core Variables

| Variable | Default | Description |
| :--- | :--- | :--- |
| `WORLD_NAME` | `world` | World filename (without `.wld`) |
| `AUTO_CREATE` | `1` | Auto-create world if not found (1=Yes, 0=No) |
| `WORLD_SIZE` | `2` | World size (1=Small, 2=Medium, 3=Large) |
| `DIFFICULTY` | `0` | Difficulty (0=Classic, 1=Expert, 2=Master, 3=Journey) |
| `SEED` | | World seed (optional) |
| `SERVER_PORT` | `7777` | Internal/External port |
| `MAX_PLAYERS` | `16` | Maximum player count |
| `SERVER_PASSWORD`| | Server password (optional) |
| `LANGUAGE` | `en-US` | Server language |
| `AUTOSAVE` | `1` | Enable in-game autosave |
| `TZ` | `Asia/Shanghai`| Container timezone |

### Backup Variables

| Variable | Default | Description |
| :--- | :--- | :--- |
| `ENABLE_BACKUP` | `1` | Enable scheduled backups |
| `BACKUP_INTERVAL`| `30` | Backup frequency in minutes |
| `BACKUP_RETAIN` | `10` | Number of backup files to keep |

> ⚠️ **Note**: `server.conf` is generated **only once**. If you change `.env` later, you must delete `config/server.conf` and restart the container to regenerate it, or edit `server.conf` manually.

---

## 💾 Backup & Restore

### Automatic Backups
Backups are triggered by a cron job inside the container. They are stored as `.tar.gz` files in the `./backups` directory.

### Manual Backup
You can trigger a backup manually at any time:
```bash
docker compose exec terraria backup.sh
```

### Restore a Backup
1. **Stop the server**: `docker compose down`
2. **List backups**: `ls ./backups`
3. **Run restore**:
   ```bash
   docker compose run --rm --entrypoint restore.sh terraria <backup_filename.tar.gz>
   ```
4. **Restart**: `docker compose up -d`

---

## 🛠️ Management

### View Logs
* **Combined Logs**: `docker compose logs -f`
* **Entrypoint Logs**: `tail -f logs/entrypoint.log`
* **Backup Logs**: `tail -f logs/backup.log`

### Interactive Console
The server runs inside a `screen` session. You can attach to it for debugging:
```bash
docker compose exec terraria screen -r terraria
```
*(To detach, press `Ctrl+A` then `D`)*

### Restart Server
```bash
docker compose restart
```

---

## 💡 Graceful Shutdown
When you run `docker compose down` or `docker stop`, the container sends a `SIGTERM` signal. The entrypoint script catches this and:
1. Notifies players in-game.
2. Executes the `save` command.
3. Performs a final backup.
4. Safely exits the server process.

**Do NOT** use `docker kill`, as it may result in data loss.

---

## 📄 License
MIT License. See [LICENSE](LICENSE) for details.

---

## ❤️ Acknowledgements
* [Terraria](https://terraria.org/) by Re-Logic.
* This project is not affiliated with or endorsed by Re-Logic.
