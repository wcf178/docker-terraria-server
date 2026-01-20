# Docker Terraria Server

**Language:** [中文](README_zh.md) | English

A Dockerized **Vanilla Terraria Server** solution that allows you to quickly deploy and run a persistent Terraria server on Linux (e.g. CentOS) using **Docker Compose**. All core configurations are managed via environment variables, with automatic world persistence, autosave, and graceful shutdown support.

> **Status**: MVP / v0.1.0
> Focus: Stable, reproducible, and beginner-friendly Terraria server deployment.

---

## ✨ Features

* Vanilla Terraria Server (no mods)
* One-command startup with `docker compose up -d`
* `.env` driven configuration → auto-generated `server.conf`
* Persistent world data via Docker volumes
* Autosave enabled by default
* Graceful shutdown (world is saved on container stop)
* Suitable for long-running servers

---

## 📦 Requirements

* Linux server (CentOS / Ubuntu / Debian recommended)
* Docker >= 20.x
* Docker Compose v2 (`docker compose`)

Optional but recommended:

* At least **1 GB RAM**
* Open port `7777` (or custom port)

---

## 🚀 Quick Start

### 1. Clone the repository

```bash
git clone https://github.com/wcf178/docker-terraria-server.git
cd docker-terraria-server
```

### 2. Create `.env` file

```bash
cp .env.example .env
```

Edit `.env` as needed (see configuration section below).

### 3. Start the server

```bash
docker compose up -d
```

### 4. Join the game

* IP: **Your server IP**
* Port: **7777** (default)
* Password: *(if configured)*

---

## ⚙️ Configuration

All configurations are controlled via environment variables and written to `server.conf` **on first startup only**.

### Core Environment Variables

| Variable          | Default         | Description                                |
| ----------------- | --------------- | ------------------------------------------ |
| `WORLD_NAME`      | `world`         | World file name (without `.wld`)           |
| `WORLD_PATH`      | `/worlds`       | World storage directory                    |
| `AUTO_CREATE`     | `1`             | Auto-create world if missing               |
| `WORLD_SIZE`      | `2`             | World size (1=Small, 2=Medium, 3=Large)    |
| `DIFFICULTY`      | `0`             | Difficulty (0=Classic, 1=Expert, 2=Master) |
| `SEED`            | *(empty)*       | World seed                                 |
| `SERVER_PORT`     | `7777`          | Server port                                |
| `MAX_PLAYERS`     | `16`            | Maximum players                            |
| `SERVER_PASSWORD` | *(empty)*       | Server password                            |
| `LANGUAGE`        | `en-US`         | Server language                            |
| `AUTOSAVE`        | `1`             | Enable autosave (recommended)              |
| `TZ`              | `Asia/Shanghai` | Container timezone                         |

> ⚠️ Once `server.conf` is generated, changing `.env` will **not overwrite** it. You must edit `server.conf` manually or delete it and restart.

---

## 🎮 Terraria Server Version

The server version is configurable via environment variable:

```env
TERRARIA_VERSION=1.4.4.9
```
On container startup:

* If the specified version is not present, it will be downloaded automatically

* Existing installations are reused

* No image rebuild is required when switching versions

---

## 💾 Automatic Backups

This project supports automatic world backups via cron.

### Configuration

```env
ENABLE_BACKUP=1
BACKUP_INTERVAL=30
BACKUP_RETAIN=10
```
### Backup Location

Backups are stored as .tar.gz files in:

```bash
/backups
```

### Restore

1. Stop the server

2. Extract a backup into /worlds

3. Restart the container

---
## 💾 Restore

### 1. stop server
docker compose down

### 2. check backups
ls /backups

### 3. restore
docker compose run --rm --entrypoint restore.sh terraria world_20260118_030000.tar.gz

### 4. restart
docker compose up -d

---

## 💾 Data Persistence

### Volumes

The following directories **must be persisted**:

* `/worlds` – Terraria world files
* `/config` – `server.conf`

Example (docker-compose.yml):

```yaml
volumes:
  - ./worlds:/worlds
  - ./config:/config
  - ./backups:/backups
```

Without volumes, world data **will be lost** on container restart.

---

## 💡 Autosave & Graceful Shutdown

### Autosave

* Enabled by default: `autosave=1`
* World is automatically saved every **5 minutes**

### Graceful Shutdown (Important)

When stopping the container:

```bash
docker compose down
```

The server will:

1. Receive `SIGTERM`
2. Execute `save`
3. Flush world data to disk
4. Exit safely

### ❌ Do NOT use

```bash
docker kill <container>
```

This may cause recent progress to roll back.

---

## 🛠️ Managing the Server

### View logs

```bash
docker compose logs -f
```

### Restart server

```bash
docker compose restart
```

### Enter container

```bash
docker compose exec terraria bash
```

---

## 🧯 Troubleshooting

### World changes not saved

Checklist:

* [ ] `autosave=1` in `server.conf`
* [ ] `/worlds` is mounted as a volume
* [ ] Container stopped via `docker compose down`

### Port not accessible

* Check firewall rules
* Ensure `SERVER_PORT` is exposed
* Confirm cloud provider security group settings

### server.conf not updating

* `server.conf` is generated **only once**
* Delete `/config/server.conf` and restart to regenerate

---

## 🗺️ Roadmap

* [ ] Automatic server version download
* [ ] Multiple world profiles
* [ ] Scheduled world backups
* [ ] TShock / tModLoader support (optional)
* [ ] Web-based management panel (optional)

---

## 🤝 Contributing

Contributions are welcome.

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Open a Pull Request

---

## 📄 License

MIT License

---

## ❤️ Acknowledgements

* Terraria by Re-Logic
* Docker community

---

## ⚠️ Disclaimer

This project is **not affiliated with or endorsed by Re-Logic**. Terraria is a registered trademark of its respective owners.
