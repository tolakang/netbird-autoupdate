# NetBird Self‑Hosted Automatic Update

A production‑ready solution to keep a NetBird self‑hosted installation on Ubuntu up‑to‑date **without unnecessary container recreation**, using **systemd timers** (no cron) and **automatic verified backups**.

---

## 📦 Installation Layout

After running the installer, files are placed in:

| Path | Purpose |
|------|---------|
| `<INSTALL_DIR>/scripts/update-netbird.sh` | Main update script (executed by systemd) |
| `/etc/systemd/system/netbird-update.service` | Systemd service unit |
| `/etc/systemd/system/netbird-update.timer` | Systemd timer unit (weekly) |
| `<INSTALL_DIR>/backups/` | Timestamped backups (auto-managed) |

> **Default `INSTALL_DIR` is `/opt/netbird`** (where NetBird quick-start installs by default).
> You can override this if NetBird is installed elsewhere.

---

## Prerequisites
- Ubuntu 20.04+ with `systemd`
- Docker Engine **with** Compose v2 plugin (`docker compose`)
- NetBird already installed via the official quick-start script
- Git installed (`sudo apt install git`)

---

## Installation

### 🚀 Quick Deploy (Recommended)

**Standard installation (NetBird at `/opt/netbird`):**
```bash copy
git clone https://github.com/tolakang/netbird-autoupdate.git && cd netbird-autoupdate && sudo ./scripts/deploy-all.sh
```

**Custom install directory** (e.g., if NetBird is at `/srv/netbird`):
```bash copy
git clone https://github.com/tolakang/netbird-autoupdate.git && cd netbird-autoupdate && sudo ./scripts/deploy-all.sh /srv/netbird
```

**Or via environment variable:**
```bash copy
sudo INSTALL_DIR=/srv/netbird ./scripts/deploy-all.sh
```

This command:
1. Validates the install directory exists and contains `docker-compose.yml`
2. Copies `update-netbird.sh` → `<INSTALL_DIR>/scripts/update-netbird.sh`
3. Copies systemd units → `/etc/systemd/system/` (with paths patched to your `INSTALL_DIR`)
4. Reloads systemd
5. Enables the weekly timer (Sun 03:00 with 15min randomization)

---

### Manual Installation (Alternative)

If you prefer step-by-step or have a custom directory:

#### 1. Clone repository
```bash copy
git clone https://github.com/tolakang/netbird-autoupdate.git
cd netbird-autoupdate
```

#### 2. Install script
```bash copy
# Default: /opt/netbird
sudo ./scripts/deploy-all.sh

# Or custom directory:
sudo ./scripts/deploy-all.sh /srv/netbird
```

#### 3. Or manually copy files:
```bash copy
# Set your NetBird directory
export NB_DIR=/opt/netbird   # change if different

# Create directories
sudo mkdir -p "$NB_DIR/scripts" /etc/systemd/system

# Copy update script
sudo cp scripts/update-netbird.sh "$NB_DIR/scripts/update-netbird.sh"
sudo chmod +x "$NB_DIR/scripts/update-netbird.sh"

# Copy systemd units
sudo cp systemd/netbird-update.service /etc/systemd/system/
sudo cp systemd/netbird-update.timer   /etc/systemd/system/

# Patch paths in service file to match your NB_DIR
sudo sed -i "s|/opt/netbird|$NB_DIR|g" /etc/systemd/system/netbird-update.service

# Enable timer
sudo systemctl daemon-reload
sudo systemctl enable --now netbird-update.timer
```

---

## How It Works
1. **Locking** – `flock` prevents overlapping runs (`/run/netbird-update.lock`).  
2. **Image check** – Pulls latest images, compares IDs, only proceeds if changed.  
3. **Consistent backup** – Stops `netbird-server`, copies **configuration files** *and* **management data directory**, restarts service.  
4. **Selective recreation** – Recreates only services with new images via `docker compose up -d --force-recreate`.  
5. **Cleanup** – Prunes dangling Docker images, retains **newest 30** backups per type.  
6. **Logging** – All output to `journalctl` under `netbird-update.service`.

---

## What Gets Backed Up?
| Type | Files / Directories | Example Backup Filenames |
|------|----------------------|--------------------------|
| Configuration | `docker-compose.yml`, `config.yaml`, `dashboard.env`, `proxy.env` | `docker-compose.yml-20231103-152400.yml`, `config.yaml-20231103-152400.yaml` |
| Management data | Entire `/var/lib/netbird/` volume from `netbird-server` container | `netbird-data-20231103-152400/` (directory) |

Each backup is timestamped, only 30 newest items per type kept.

---

## Monitoring & Manual Controls
| Action | Command |
|--------|---------|
| View next scheduled run | `systemctl list-timers netbird-update.timer` |
| Run update immediately (for testing) | `sudo systemctl start netbird-update.service` |
| View recent logs | `journalctl -u netbird-update.service -n 100 --no-pager` |

---

## Customisation
- **Change NetBird directory** – run `./scripts/deploy-all.sh /new/path` or edit `Environment=COMPOSE_DIR=` in the service file
- **Adjust schedule** – modify `OnCalendar` in `/etc/systemd/system/netbird-update.timer` (e.g., `OnCalendar=Mon *-*-* 02:00`)
- **Retention count** – edit `tail -n +31` in the update script (`+31` → `+<N+1>` for different limit)
- **Custom services list** – set `SERVICES="svc1 svc2"` environment variable before running

---

## Security Hardening (systemd)
- `ProtectSystem=full` – root filesystem read-only for service  
- `PrivateTmp=yes` – isolates `/tmp`  
- `ReadWritePaths=<INSTALL_DIR> <INSTALL_DIR>/backups /run` – limited write permissions  
- `Nice=10` – lowers CPU priority

---

## License
MIT – see [LICENSE](https://github.com/tolakang/netbird-autoupdate/blob/main/LICENSE).