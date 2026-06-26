# NetBird Self‑Hosted Automatic Update

A production‑ready solution to keep a NetBird self‑hosted installation on Ubuntu up‑to‑date **without unnecessary container recreation**, using **systemd timers** (no cron) and **automatic verified backups**.

> **🔍 Auto-detects your NetBird install directory** — works with `/opt/netbird`, `/srv/netbird`, `/home/*/netbird`, or any custom location.

---

## 📦 Installation Layout

After running the installer, files are placed in:

| Path | Purpose |
|------|---------|
| `<INSTALL_DIR>/scripts/update-netbird.sh` | Main update script (executed by systemd) |
| `/etc/systemd/system/netbird-update.service` | Systemd service unit |
| `/etc/systemd/system/netbird-update.timer` | Systemd timer unit (weekly) |
| `<INSTALL_DIR>/backups/` | Timestamped backups (auto-managed) |
| `/etc/netbird-autoupdate.conf` | Saved install path (for future runs) |

> **`INSTALL_DIR` is auto-detected** from common locations. You can override manually if needed.

---

## Prerequisites
- Ubuntu 20.04+ with `systemd`
- Docker Engine **with** Compose v2 plugin (`docker compose`)
- NetBird already installed via the official quick-start script
- Git installed (`sudo apt install git`)

---

## Installation

### 🚀 One-Line Install (Easiest)

**Auto-detect install directory:**
```bash copy
curl -fsSL https://raw.githubusercontent.com/tolakang/netbird-autoupdate/main/quick-install.sh | sudo bash
```

**With explicit install path:**
```bash copy
curl -fsSL https://raw.githubusercontent.com/tolakang/netbird-autoupdate/main/quick-install.sh | sudo bash /srv/netbird
```

This command:
1. ✅ Clones repo to `/opt/netbird-autoupdate-repo` (or updates if exists)
2. ✅ Runs `deploy-all.sh` with auto-detection
3. ✅ Works even if you've cloned the repo before (no "directory exists" error)

---

### 🚀 Quick Deploy (Manual Clone)

**Zero-config (auto-detects install directory):**
```bash copy
git clone https://github.com/tolakang/netbird-autoupdate.git && cd netbird-autoupdate && sudo ./scripts/deploy-all.sh
```

> **If you get "destination path already exists"**, either delete the directory first:
> ```bash
> rm -rf netbird-autoupdate
> git clone https://github.com/tolakang/netbird-autoupdate.git && cd netbird-autoupdate && sudo ./scripts/deploy-all.sh
> ```
> Or use the one-line installer above which handles this automatically.

The installer will automatically search these locations:
- `/opt/netbird` (default)
- `/srv/netbird`
- `/home/netbird`
- `/var/lib/netbird`
- `/etc/netbird`
- `/usr/local/netbird`
- `/home/<user>/netbird`, `/home/<user>/netbird-host`, `/home/<user>/netbird-selfhost`
- Any `/home/*/netbird*` directory

It validates the found directory contains a NetBird `docker-compose.yml` (checks for `netbird-server` or `netbirdio/` images).

---

### Manual Override

If auto-detection fails, or to specify a custom path:

**With command argument:**
```bash copy
sudo ./scripts/deploy-all.sh /srv/netbird
```

**With environment variable:**
```bash copy
sudo INSTALL_DIR=/srv/netbird ./scripts/deploy-all.sh
```

**With persistent config file:**
```bash copy
echo 'INSTALL_DIR=/srv/netbird' | sudo tee /etc/netbird-autoupdate.conf
sudo ./scripts/deploy-all.sh
```

This command:
1. **Auto-detects** (or uses specified) install directory
2. **Validates** the directory contains a valid NetBird `docker-compose.yml`
3. **Copies** `update-netbird.sh` → `<INSTALL_DIR>/scripts/update-netbird.sh`
4. **Copies** systemd units → `/etc/systemd/system/` (paths auto-patched)
5. **Reloads** systemd
6. **Enables** the weekly timer (Sun 03:00 with 15min randomization)
7. **Saves** the path to `/etc/netbird-autoupdate.conf` for future runs

---

### Manual Installation (Alternative)

If you prefer step-by-step or want full control:

#### 1. Clone repository
```bash copy
git clone https://github.com/tolakang/netbird-autoupdate.git
cd netbird-autoupdate
```

#### 2. Run installer with custom path:
```bash copy
sudo ./scripts/deploy-all.sh /your/netbird/path
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
| View saved install path | `cat /etc/netbird-autoupdate.conf` |
| Re-run with saved path | `sudo ./scripts/deploy-all.sh` |

---

## Customisation
- **Change NetBird directory** – run `./scripts/deploy-all.sh /new/path` or edit `/etc/netbird-autoupdate.conf`
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

## 🗑️ Uninstall

To remove the NetBird auto-update system completely:

### One-Line Uninstall (Easiest)
```bash copy
curl -fsSL https://raw.githubusercontent.com/tolakang/netbird-autoupdate/main/quick-uninstall.sh | sudo bash
```

### With explicit install path:
```bash copy
curl -fsSL https://raw.githubusercontent.com/tolakang/netbird-autoupdate/main/quick-uninstall.sh | sudo bash /srv/netbird
```

### Or if repo is cloned locally:
```bash copy
cd /opt/netbird-autoupdate-repo
sudo ./scripts/uninstall.sh
```

### Or with auto-detect from repo dir:
```bash copy
sudo /opt/netbird-autoupdate-repo/scripts/uninstall.sh
```

### With explicit path:
```bash copy
sudo ./scripts/uninstall.sh /srv/netbird
```

### Or using the saved config:
```bash copy
sudo ./scripts/uninstall.sh $(cat /etc/netbird-autoupdate.conf | cut -d'"' -f2)
```

### What gets removed:
- ✅ `/etc/systemd/system/netbird-update.service` (systemd service)
- ✅ `/etc/systemd/system/netbird-update.timer` (systemd timer)
- ✅ `<INSTALL_DIR>/scripts/update-netbird.sh` (update script)
- ✅ `/etc/netbird-autoupdate.conf` (saved install path)
- ✅ `/run/netbird-update.lock` (lock file)
- ✅ systemd daemon is reloaded to clear cached references

### What is preserved:
- ✅ **Backups** in `<INSTALL_DIR>/backups/`
- ✅ **NetBird itself** (docker-compose.yml, config.yaml, etc.)
- ✅ **Docker images** and containers (not touched)

### To completely remove everything (including backups):
```bash copy
sudo ./scripts/uninstall.sh
sudo rm -rf $(cat /etc/netbird-autoupdate.conf 2>/dev/null | cut -d'"' -f2)/backups/
```

---

## License
MIT – see [LICENSE](https://github.com/tolakang/netbird-autoupdate/blob/main/LICENSE).