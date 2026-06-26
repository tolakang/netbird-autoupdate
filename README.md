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

## 🚀 Installation

### One-Line Install (Easiest)

**Auto-detect install directory:**
```bash
curl -fsSL https://raw.githubusercontent.com/tolakang/netbird-autoupdate/main/quick-install.sh | sudo bash -s --
```

**With explicit install path:**
```bash
curl -fsSL https://raw.githubusercontent.com/tolakang/netbird-autoupdate/main/quick-install.sh | sudo bash -s -- /srv/netbird
```

> **Note:** The `-s --` after `sudo bash` is important:
> - `-s` tells bash to read the script from stdin (the piped curl output)
> - `--` separates bash options from positional arguments
> - Arguments after `--` are passed to the script (e.g., the install directory)

This command:
1. ✅ Clones repo to `/opt/netbird-autoupdate-repo` (always fresh - removes old if exists)
2. ✅ Runs `deploy-all.sh` with auto-detection
3. ✅ Works even if you've cloned the repo before (no "directory exists" error)

---

### Quick Deploy (Manual Clone)

**Zero-config (auto-detects install directory):**
```bash
git clone https://github.com/tolakang/netbird-autoupdate.git && cd netbird-autoupdate && sudo ./scripts/deploy-all.sh
```

**With custom path:**
```bash
sudo ./scripts/deploy-all.sh /srv/netbird
```

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

### Manual Installation (Step-by-step)

If you prefer full control:

```bash
# 1. Clone repository
git clone https://github.com/tolakang/netbird-autoupdate.git
cd netbird-autoupdate

# 2. Set your NetBird directory
export NB_DIR=/opt/netbird   # change if different

# 3. Create directories
sudo mkdir -p "$NB_DIR/scripts" /etc/systemd/system

# 4. Copy update script
sudo cp scripts/update-netbird.sh "$NB_DIR/scripts/update-netbird.sh"
sudo chmod +x "$NB_DIR/scripts/update-netbird.sh"

# 5. Copy systemd units
sudo cp systemd/netbird-update.service /etc/systemd/system/
sudo cp systemd/netbird-update.timer   /etc/systemd/system/

# 6. Patch paths in service file to match your NB_DIR
sudo sed -i "s|/opt/netbird|$NB_DIR|g" /etc/systemd/system/netbird-update.service

# 7. Enable timer
sudo systemctl daemon-reload
sudo systemctl enable --now netbird-update.timer
```

---

## How It Works

1. **Locking** – `flock` prevents overlapping runs (`/run/netbird-update.lock`).  
2. **Image check** – Pulls latest images, compares IDs, only proceeds if changed.  
3. **Consistent backup** – Stops `netbird-server`, copies **configuration files** *and* **management data directory**, restarts service.  
4. **Selective recreation** – Recreates only services with new images via `docker compose up -d --force-recreate`.  
5. **Cleanup** – Prunes dangling Docker images, retains **newest N** backups per type.  
6. **Logging** – All output to `journalctl` under `netbird-update.service`.

---

## What Gets Backed Up?

| Type | Files / Directories | Example Backup Filenames |
|------|----------------------|--------------------------|
| Configuration | `docker-compose.yml`, `config.yaml`, `dashboard.env`, `proxy.env` | `docker-compose.yml-20231103-152400.yml`, `config.yaml-20231103-152400.yaml` |
| Management data | Entire `/var/lib/netbird/` volume from `netbird-server` container | `netbird-data-20231103-152400/` (directory) |

Each backup is timestamped, only 30 newest items per type kept (configurable via `BACKUP_RETENTION`).

---

## Monitoring & Manual Controls

| Action | Command |
|--------|---------|
| View next scheduled run | `systemctl list-timers netbird-update.timer` |
| Run update immediately (for testing) | `sudo systemctl start netbird-update.service` |
| View recent logs | `journalctl -u netbird-update.service -n 100 --no-pager` |
| View saved install path | `cat /etc/netbird-autoupdate.conf` |
| Re-run with saved path | `sudo /opt/netbird-autoupdate-repo/scripts/deploy-all.sh` |

---

## Customisation

All customizations are done via environment variables in the systemd service:

```bash
sudo systemctl edit netbird-update.service
```

Add (or modify) the `Environment=` lines:
```ini
[Service]
Environment=COMPOSE_DIR=/srv/netbird
Environment=SERVICES="netbird-server dashboard proxy"
Environment=BACKUP_FILES="docker-compose.yml config.yaml dashboard.env proxy.env"
Environment=BACKUP_RETENTION=30
```

Then reload:
```bash
sudo systemctl daemon-reload
```

---

## Security Hardening (systemd)

- `ProtectSystem=full` – root filesystem read-only for service  
- `PrivateTmp=yes` – isolates `/tmp`  
- `ReadWritePaths=<INSTALL_DIR> <INSTALL_DIR>/backups /run` – limited write permissions  
- `Nice=10` – lowers CPU priority  
- `IOSchedulingClass=best-effort` – reduces I/O contention

---

## 🗑️ Uninstall

### One-Line Uninstall (Easiest)

```bash
curl -fsSL https://raw.githubusercontent.com/tolakang/netbird-autoupdate/main/quick-uninstall.sh | sudo bash -s --
```

**With explicit install path:**
```bash
curl -fsSL https://raw.githubusercontent.com/tolakang/netbird-autoupdate/main/quick-uninstall.sh | sudo bash -s -- /srv/netbird
```

> **Note:** Use `sudo bash -s --` (not just `sudo bash`) so arguments are passed correctly to the script.

### Manual Uninstall

```bash
sudo /opt/netbird-autoupdate-repo/scripts/uninstall.sh
# or with path:
sudo /opt/netbird-autoupdate-repo/scripts/uninstall.sh /srv/netbird
```

### Force Interactive Mode

If piped via curl, the script auto-proceeds. To force an interactive confirmation:

```bash
NETBIRD_FORCE_INTERACTIVE=1 curl -fsSL https://raw.githubusercontent.com/tolakang/netbird-autoupdate/main/quick-uninstall.sh | sudo bash -s --
```

### Force Abort (Non-Interactive)

```bash
NONINTERACTIVE=1 curl -fsSL https://raw.githubusercontent.com/tolakang/netbird-autoupdate/main/quick-uninstall.sh | sudo bash -s --
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

```bash
curl -fsSL https://raw.githubusercontent.com/tolakang/netbird-autoupdate/main/quick-uninstall.sh | sudo bash
sudo rm -rf /opt/netbird/backups/   # adjust to your install dir
```

---

## 🛠️ Troubleshooting

### "dubious ownership" error

Already handled in quick-install.sh. If you encounter this manually:
```bash
git config --global --add safe.directory /path/to/repo
```

### Update script not found after install

The systemd service expects the script at the configured `INSTALL_DIR/scripts/update-netbird.sh`. Check:
```bash
cat /etc/netbird-autoupdate.conf
sudo systemctl show netbird-update.service | grep ExecStart
```

### Check logs

```bash
sudo journalctl -u netbird-update.service -n 50 --no-pager
```

---

## 📂 Repository Structure

```
netbird-autoupdate/
├── quick-install.sh        # One-line installer (curl-pipable)
├── quick-uninstall.sh      # One-line uninstaller (curl-pipable)
├── README.md
├── .gitignore
├── scripts/
│   ├── deploy-all.sh       # Main deployment script
│   ├── uninstall.sh        # Self-contained uninstaller
│   ├── update-netbird.sh   # Main update logic (runs weekly)
│   └── lib/
│       └── common.sh       # Shared library functions
└── systemd/
    ├── netbird-update.service
    └── netbird-update.timer
```

---

## License

MIT – see [LICENSE](https://github.com/tolakang/netbird-autoupdate/blob/main/LICENSE).