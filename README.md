# NetBird Self‑Hosted Automatic Update

A production‑ready solution to keep a NetBird self‑hosted installation on Ubuntu up‑to‑date **without unnecessary container recreation**, using **systemd timers** (no cron) and **automatic verified backups**.

---

## 📦 Installation Layout

After running the installer, files are placed in:

| Path | Purpose |
|------|---------|
| `/opt/netbird/scripts/update-netbird.sh` | Main update script (executed by systemd) |
| `/etc/systemd/system/netbird-update.service` | Systemd service unit |
| `/etc/systemd/system/netbird-update.timer` | Systemd timer unit (weekly) |
| `/opt/netbird/backups/` | Timestamped backups (auto-managed) |

---

## Prerequisites
- Ubuntu 20.04+ with `systemd`
- Docker Engine **with** Compose v2 plugin (`docker compose`)
- NetBird already installed via the official quick-start script (defaults to `/opt/netbird`)
- Git installed (`sudo apt install git`)

---

## Installation

### 🚀 Quick Deploy (Recommended)

**One-command deployment:**
```bash copy
git clone https://github.com/tolakang/netbird-autoupdate.git && cd netbird-autoupdate && sudo ./scripts/deploy-all.sh
```

This single command:
1. Copies `update-netbird.sh` → `/opt/netbird/scripts/update-netbird.sh`
2. Copies systemd units → `/etc/systemd/system/`
3. Reloads systemd
4. Enables the weekly timer (Sun 03:00 with 15min randomization)

---

### Manual Installation (Alternative)

If you prefer step-by-step:

#### 1. Clone repository
```bash copy
git clone https://github.com/tolakang/netbird-autoupdate.git
cd netbird-autoupdate
```

#### 2. Create directories
```bash copy
sudo mkdir -p /opt/netbird/scripts /etc/systemd/system
```

#### 3. Copy files
```bash copy
# Update script
sudo cp scripts/update-netbird.sh /opt/netbird/scripts/update-netbird.sh
sudo chmod +x /opt/netbird/scripts/update-netbird.sh

# Systemd units (must go to /etc/systemd/system/)
sudo cp systemd/netbird-update.service /etc/systemd/system/
sudo cp systemd/netbird-update.timer   /etc/systemd/system/
```

#### 4. Enable and start the timer
```bash copy
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
- **Change NetBird directory** – edit `/etc/systemd/system/netbird-update.service`, add `Environment=COMPOSE_DIR=/new/path`
- **Adjust schedule** – modify `OnCalendar` in `/etc/systemd/system/netbird-update.timer` (e.g., `OnCalendar=Mon *-*-* 02:00`)
- **Retention count** – edit `tail -n +31` in `/opt/netbird/scripts/update-netbird.sh` (`+31` → `+<N+1>` for different limit)

---

## Security Hardening (systemd)
- `ProtectSystem=full` – root filesystem read-only for service  
- `PrivateTmp=yes` – isolates `/tmp`  
- `ReadWritePaths=/opt/netbird /opt/netbird/backups /run` – limited write permissions  
- `Nice=10` – lowers CPU priority

---

## License
MIT – see [LICENSE](https://github.com/tolakang/netbird-autoupdate/blob/main/LICENSE).