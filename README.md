# NetBird Self‑Hosted Automatic Update

A production‑ready solution to keep a NetBird self‑hosted installation on Ubuntu up‑to‑date **without unnecessary container recreation**, using **systemd timers** (no cron) and **automatic verified backups**.

---

## 📦 Repository Structure
```
/opt/netbird/
├─ scripts/
│  └─ update-netbird.sh          # Main update script (see below)
├─ systemd/
│  ├─ netbird-update.service    # systemd service definition
│  └─ netbird-update.timer      # weekly timer (Sun 03:00)
└─ backups/                      # Timestamped backups (auto‑managed)
```

---

## Prerequisites
- Ubuntu 20.04 + with `systemd`
- Docker Engine **with** Compose v2 plugin (`docker compose`)
- NetBird already installed via the official quick‑start script (defaults to `/opt/netbird`)

---

## Installation
All commands below include a **Copy** button for easy pasting into your terminal.

### 1. Deploy the update script
```bash copy
sudo mkdir -p /opt/netbird/scripts
sudo curl -fsSL https://raw.githubusercontent.com/tolakang/netbird-autoupdate/main/scripts/update-netbird.sh \
    -o /opt/netbird/scripts/update-netbird.sh
sudo chmod +x /opt/netbird/scripts/update-netbird.sh
```

### 2. Install the systemd service
```bash copy
sudo mkdir -p /etc/systemd/system
sudo cp /opt/netbird/systemd/netbird-update.service /etc/systemd/system/
```

### 3. Install the systemd timer
```bash copy
sudo cp /opt/netbird/systemd/netbird-update.timer /etc/systemd/system/
```

### 4. Enable and start the timer
```bash copy
sudo systemctl daemon-reload
sudo systemctl enable --now netbird-update.timer
```

---

## How It Works
1. **Locking** – `flock` prevents overlapping runs (`/run/netbird-update.lock`).  
2. **Image check** – Pulls the latest images, compares IDs, and only proceeds if any changed.  
3. **Consistent backup** – Stops `netbird-server`, copies **configuration files** *and* the **management data directory**, then restarts the service.  
4. **Selective recreation** – Recreates only the services with new images using `docker compose up -d --force-recreate`.  
5. **Cleanup** – Prunes dangling Docker images and retains the **newest 30** backups per file type and data directory.  
6. **Logging** – All output goes to `journalctl` under the unit `netbird-update.service`.

---

## What Gets Backed Up?
| Type | Files / Directories | Example Backup Filenames |
|------|----------------------|--------------------------|
| Configuration | `docker-compose.yml`, `config.yaml`, `dashboard.env`, `proxy.env` | `docker-compose.yml-20231103-152400.yml`, `config.yaml-20231103-152400.yaml` |
| Management data | Entire `/var/lib/netbird/` volume from the `netbird-server` container | `netbird-data-20231103-152400/` (directory) |

Each backup is timestamped, and only the 30 newest items per type are kept.

---

## Monitoring & Manual Controls
| Action | Command |
|--------|---------|
| View next scheduled run | `systemctl list-timers netbird-update.timer` |
| Run update immediately (for testing) | `sudo systemctl start netbird-update.service` |
| View recent logs | `journalctl -u netbird-update.service -n 100 --no-pager` |

---

## Customisation
- **Change the NetBird directory** – edit `netbird-update.service` and add an `Environment=` line pointing to the new path.  
- **Adjust schedule** – modify `OnCalendar` in `netbird-update.timer` (e.g., `OnCalendar=Mon *-*-* 02:00`).  
- **Retention count** – edit the `tail -n +31` numbers in the script (`+31` → `+<N+1>` for a different roll‑back limit).  

---

## Security Hardening (systemd)
- `ProtectSystem=full` – makes the root filesystem read‑only for the service.  
- `PrivateTmp=yes` – isolates `/tmp`.  
- `ReadWritePaths=/opt/netbird /opt/netbird/backups /run` – limits write permissions to the essential directories.  
- `Nice=10` – lowers CPU priority.

---

## License
MIT – see [LICENSE](https://github.com/tolakang/netbird-autoupdate/blob/main/LICENSE).