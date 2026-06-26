#!/usr/bin/env bash

# Auto-deploy NetBird auto-update system from repository
# Usage: sudo ./scripts/deploy-all.sh [INSTALL_DIR]
#
# Auto-detects NetBird installation directory by searching common locations.
# Override with:
#   - Argument:    sudo ./scripts/deploy-all.sh /srv/netbird
#   - Env variable: INSTALL_DIR=/srv/netbird sudo ./scripts/deploy-all.sh
#   - Config file:  /etc/netbird-autoupdate.conf containing INSTALL_DIR=/path

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
echo "Deploying NetBird auto-update system from: $REPO_ROOT"

# Load config file if it exists (for persistence)
if [[ -f /etc/netbird-autoupdate.conf ]]; then
    # shellcheck disable=SC1091
    source /etc/netbird-autoupdate.conf
fi

# Function to detect NetBird installation directory
detect_netbird_dir() {
    local candidate
    local search_paths=(
        "/opt/netbird"
        "/srv/netbird"
        "/home/netbird"
        "/var/lib/netbird"
        "/etc/netbird"
        "/usr/local/netbird"
    )

    # Also check the current user's home and common user dirs
    if [[ -n "${SUDO_USER:-}" ]]; then
        local user_home
        user_home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
        if [[ -n "$user_home" ]]; then
            search_paths+=("$user_home/netbird")
            search_paths+=("$user_home/netbird-host")
            search_paths+=("$user_home/netbird-selfhost")
        fi
    fi

    # Also check /home/* for any user with a netbird directory
    for user_dir in /home/*/; do
        search_paths+=("${user_dir}netbird")
        search_paths+=("${user_dir}netbird-host")
        search_paths+=("${user_dir}netbird-selfhost")
    done

    for candidate in "${search_paths[@]}"; do
        if [[ -f "$candidate/docker-compose.yml" ]]; then
            # Verify it's actually a NetBird compose file
            if grep -q "netbird-server\|netbirdio/" "$candidate/docker-compose.yml" 2>/dev/null; then
                echo "$candidate"
                return 0
            fi
        fi
    done

    return 1
}

# Determine install directory: argument > env var > config file > auto-detect > default
INSTALL_DIR="${1:-${INSTALL_DIR:-}}"

if [[ -z "$INSTALL_DIR" ]]; then
    echo "Auto-detecting NetBird installation directory..."
    if INSTALL_DIR=$(detect_netbird_dir); then
        echo "✅ Found NetBird installation at: $INSTALL_DIR"
    else
        echo "❌ Could not auto-detect NetBird installation."
        echo ""
        echo "Please specify the directory manually:"
        echo "  sudo ./scripts/deploy-all.sh /path/to/netbird"
        echo ""
        echo "Common locations searched:"
        echo "  /opt/netbird, /srv/netbird, /home/*/netbird, /var/lib/netbird, etc."
        exit 1
    fi
else
    echo "Using specified install directory: $INSTALL_DIR"
fi

# Validate install directory and compose file
if [[ ! -d "$INSTALL_DIR" ]]; then
    echo "❌ ERROR: Directory does not exist: $INSTALL_DIR"
    exit 1
fi

if [[ ! -f "$INSTALL_DIR/docker-compose.yml" ]]; then
    echo "❌ ERROR: docker-compose.yml not found in: $INSTALL_DIR"
    echo "   Ensure NetBird is installed in this directory."
    exit 1
fi

# Verify this looks like a NetBird install
if ! grep -q "netbird-server\|netbirdio/" "$INSTALL_DIR/docker-compose.yml" 2>/dev/null; then
    echo "⚠️  WARNING: docker-compose.yml does not appear to contain NetBird services."
    echo "   Found at: $INSTALL_DIR"
    read -rp "   Continue anyway? [y/N] " response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
fi

# Save the detected directory for future runs
echo "INSTALL_DIR=\"$INSTALL_DIR\"" | sudo tee /etc/netbird-autoupdate.conf > /dev/null

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  NetBird Home:    $INSTALL_DIR"
echo "  Update Script:   $INSTALL_DIR/scripts/update-netbird.sh"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Ensure destination directories exist
sudo mkdir -p "$INSTALL_DIR/scripts"
sudo mkdir -p /etc/systemd/system

# Copy update script
echo "📦 Installing update script..."
sudo cp "$REPO_ROOT/scripts/update-netbird.sh" "$INSTALL_DIR/scripts/update-netbird.sh"
sudo chmod +x "$INSTALL_DIR/scripts/update-netbird.sh"

# Copy systemd unit files
echo "📦 Installing systemd units..."
sudo cp "$REPO_ROOT/systemd/netbird-update.service" /etc/systemd/system/netbird-update.service
sudo cp "$REPO_ROOT/systemd/netbird-update.timer"   /etc/systemd/system/netbird-update.timer

# Patch the service file to use the correct install directory
sudo sed -i "s|/opt/netbird|$INSTALL_DIR|g" /etc/systemd/system/netbird-update.service

# Reload systemd to recognize new units
sudo systemctl daemon-reload

# Enable and start the timer (service will run on schedule)
sudo systemctl enable --now netbird-update.timer

echo ""
echo "✅ NetBird auto-update system deployed successfully!"
echo ""
echo "   📍 Update script:  $INSTALL_DIR/scripts/update-netbird.sh"
echo "   📍 NetBird home:   $INSTALL_DIR"
echo "   📍 Systemd units:  /etc/systemd/system/"
echo "   ⏰ Timer enabled:  weekly on Sunday 03:00 (with 15min randomization)"
echo "   💾 Config saved:   /etc/netbird-autoupdate.conf"
echo ""
echo "Useful commands:"
echo "   systemctl list-timers netbird-update.timer    # View schedule"
echo "   sudo systemctl start netbird-update.service  # Run update now"
echo "   journalctl -u netbird-update.service -f      # View logs"