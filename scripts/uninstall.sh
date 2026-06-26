#!/usr/bin/env bash

# Uninstall NetBird auto-update system
# Removes all files, systemd units, and configuration created by deploy-all.sh
#
# Usage: sudo ./scripts/uninstall.sh [INSTALL_DIR]
#   INSTALL_DIR: NetBird installation directory (auto-detects if not specified)

set -uo pipefail

# Load saved config if exists
if [[ -f /etc/netbird-autoupdate.conf ]]; then
    # shellcheck disable=SC1091
    source /etc/netbird-autoupdate.conf
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  NetBird Auto-Update Uninstaller"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Determine install directory
INSTALL_DIR="${1:-${INSTALL_DIR:-}}"

# Function to detect NetBird directory
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

    if [[ -n "${SUDO_USER:-}" ]]; then
        local user_home
        user_home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
        if [[ -n "$user_home" ]]; then
            search_paths+=("$user_home/netbird")
            search_paths+=("$user_home/netbird-host")
            search_paths+=("$user_home/netbird-selfhost")
        fi
    fi

    for user_dir in /home/*/; do
        search_paths+=("${user_dir}netbird")
        search_paths+=("${user_dir}netbird-host")
        search_paths+=("${user_dir}netbird-selfhost")
    done

    for candidate in "${search_paths[@]}"; do
        if [[ -f "$candidate/scripts/update-netbird.sh" ]]; then
            echo "$candidate"
            return 0
        fi
    done

    return 1
}

if [[ -z "$INSTALL_DIR" ]]; then
    echo "Auto-detecting NetBird installation..."
    if INSTALL_DIR=$(detect_netbird_dir); then
        echo "✅ Found NetBird installation at: $INSTALL_DIR"
    else
        echo "⚠️  Could not auto-detect. Using default: /opt/netbird"
        INSTALL_DIR="/opt/netbird"
    fi
else
    echo "Using specified directory: $INSTALL_DIR"
fi

echo ""
echo "This will remove:"
echo "  • Systemd service: /etc/systemd/system/netbird-update.service"
echo "  • Systemd timer:   /etc/systemd/system/netbird-update.timer"
echo "  • Update script:   $INSTALL_DIR/scripts/update-netbird.sh"
echo "  • Config file:     /etc/netbird-autoupdate.conf"
echo "  • Lock file:       /run/netbird-update.lock"
echo ""
echo "Note: Backups in $INSTALL_DIR/backups/ will be PRESERVED"
echo "      NetBird itself will NOT be touched"
echo ""

read -rp "Continue with uninstall? [y/N] " response
if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "🗑️  Stopping and disabling systemd units..."

# Stop and disable timer (if running)
if command -v systemctl >/dev/null 2>&1; then
    if systemctl is-active --quiet netbird-update.timer 2>/dev/null; then
        sudo systemctl stop netbird-update.timer || true
        echo "   Stopped timer"
    fi

    if systemctl is-active --quiet netbird-update.service 2>/dev/null; then
        sudo systemctl stop netbird-update.service || true
        echo "   Stopped service"
    fi

    if systemctl is-enabled --quiet netbird-update.timer 2>/dev/null; then
        sudo systemctl disable netbird-update.timer || true
        echo "   Disabled timer"
    fi

    # Reload systemd
    sudo systemctl daemon-reload || true
    sudo systemctl reset-failed netbird-update.service netbird-update.timer 2>/dev/null || true
else
    echo "   (systemctl not available, skipping service management)"
fi

echo ""
echo "🗑️  Removing systemd unit files..."
sudo rm -f /etc/systemd/system/netbird-update.service
sudo rm -f /etc/systemd/system/netbird-update.timer
echo "   Removed /etc/systemd/system/netbird-update.service"
echo "   Removed /etc/systemd/system/netbird-update.timer"

echo ""
echo "🗑️  Removing update script..."
if [[ -f "$INSTALL_DIR/scripts/update-netbird.sh" ]]; then
    sudo rm -f "$INSTALL_DIR/scripts/update-netbird.sh"
    echo "   Removed $INSTALL_DIR/scripts/update-netbird.sh"
else
    echo "   Update script not found (already removed?)"
fi

echo ""
echo "🗑️  Removing config and lock files..."
sudo rm -f /etc/netbird-autoupdate.conf
echo "   Removed /etc/netbird-autoupdate.conf"

if [[ -f /run/netbird-update.lock ]]; then
    sudo rm -f /run/netbird-update.lock
    echo "   Removed /run/netbird-update.lock"
fi

# Final daemon reload to clear any cached references
if command -v systemctl >/dev/null 2>&1; then
    sudo systemctl daemon-reload || true
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Uninstall complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Removed components:"
echo "  ✓ Systemd service and timer"
echo "  ✓ Update script"
echo "  ✓ Configuration files"
echo "  ✓ Lock file"
echo ""
echo "Preserved:"
echo "  • Backups at: $INSTALL_DIR/backups/"
echo "  • NetBird installation itself at: $INSTALL_DIR/"
echo ""
echo "To completely remove backups too (optional):"
echo "  sudo rm -rf $INSTALL_DIR/backups/"
echo ""
echo "To reinstall, run:"
echo "  sudo ./scripts/deploy-all.sh"