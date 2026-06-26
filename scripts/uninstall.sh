#!/usr/bin/env bash

# Uninstall NetBird auto-update system
# Removes all files, systemd units, and configuration created by deploy-all.sh
#
# Usage: sudo ./scripts/uninstall.sh [INSTALL_DIR]
#   INSTALL_DIR: NetBird installation directory (auto-detects if not specified)
#
# Self-contained script - can be run directly from cloned repo or via
# curl download (no external library dependencies).

set -uo pipefail

# Configuration (embedded for self-contained execution)
NETBIRD_AUTOUPDATE_CONF="/etc/netbird-autoupdate.conf"
NETBIRD_DEFAULT_PATHS=(
    "/opt/netbird"
    "/srv/netbird"
    "/home/netbird"
    "/var/lib/netbird"
    "/etc/netbird"
    "/usr/local/netbird"
)

# Helper functions
log_info() { echo "ℹ️  $*"; }
log_success() { echo "✅ $*"; }
log_warn() { echo "⚠️  $*"; }
log_error() { echo "❌ $*"; }
log_step() { echo "🗑️  $*"; }

# Detect NetBird directory by looking for update script
detect_netbird_dir_script() {
    local candidate
    local search_paths=("${NETBIRD_DEFAULT_PATHS[@]}")

    if [[ -n "${SUDO_USER:-}" ]]; then
        local user_home
        user_home=$(getent passwd "$SUDO_USER" | cut -d: -f6 2>/dev/null)
        if [[ -n "$user_home" ]]; then
            search_paths+=(
                "$user_home/netbird"
                "$user_home/netbird-host"
                "$user_home/netbird-selfhost"
            )
        fi
    fi

    for user_dir in /home/*/; do
        [[ -d "$user_dir" ]] || continue
        search_paths+=(
            "${user_dir}netbird"
            "${user_dir}netbird-host"
            "${user_dir}netbird-selfhost"
        )
    done

    for candidate in "${search_paths[@]}"; do
        if [[ -f "$candidate/scripts/update-netbird.sh" ]]; then
            echo "$candidate"
            return 0
        fi
    done

    return 1
}

# Confirm action - safe for piped execution
# When running interactively (terminal attached): asks for confirmation
# When running via pipe (e.g., curl | bash): auto-proceeds unless NONINTERACTIVE=1
confirm() {
    local message="${1:-Continue?}"

    if [[ -t 0 ]] || [[ "${NETBIRD_FORCE_INTERACTIVE:-0}" == "1" ]]; then
        local response
        read -rp "$message [y/N] " response
        [[ "$response" =~ ^[Yy]$ ]]
    else
        echo "$message [auto-yes: piped/non-interactive mode]" >&2
        if [[ "${NONINTERACTIVE:-0}" == "1" ]]; then
            echo "NONINTERACTIVE=1 set, aborting." >&2
            return 1
        fi
        return 0
    fi
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  NetBird Auto-Update Uninstaller"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Determine install directory
if [[ -z "${INSTALL_DIR:-}" ]] && [[ $# -gt 0 ]]; then
    INSTALL_DIR="$1"
fi

# Auto-detect if still empty
if [[ -z "${INSTALL_DIR:-}" ]]; then
    log_info "Auto-detecting NetBird installation..."
    if INSTALL_DIR=$(detect_netbird_dir_script); then
        log_success "Found NetBird installation at: $INSTALL_DIR"
    else
        log_warn "Could not auto-detect. Using default: /opt/netbird"
        INSTALL_DIR="/opt/netbird"
    fi
else
    log_info "Using directory: $INSTALL_DIR"
fi

echo ""
echo "This will remove:"
echo "  • Systemd service: /etc/systemd/system/netbird-update.service"
echo "  • Systemd timer:   /etc/systemd/system/netbird-update.timer"
echo "  • Update script:   $INSTALL_DIR/scripts/update-netbird.sh"
echo "  • Config file:     $NETBIRD_AUTOUPDATE_CONF"
echo "  • Lock file:       /run/netbird-update.lock"
echo ""
echo "Note: Backups in $INSTALL_DIR/backups/ will be PRESERVED"
echo "      NetBird itself will NOT be touched"
echo ""

if ! confirm "Continue with uninstall?"; then
    echo "Aborted."
    exit 0
fi

echo ""
log_step "Stopping and disabling systemd units..."

if command -v systemctl >/dev/null 2>&1; then
    sudo systemctl stop netbird-update.timer 2>/dev/null || true
    sudo systemctl stop netbird-update.service 2>/dev/null || true
    sudo systemctl disable netbird-update.timer 2>/dev/null || true
    sudo systemctl daemon-reload 2>/dev/null || true
    sudo systemctl reset-failed netbird-update.service netbird-update.timer 2>/dev/null || true
fi

echo ""
log_step "Removing systemd unit files..."
sudo rm -f /etc/systemd/system/netbird-update.service
sudo rm -f /etc/systemd/system/netbird-update.timer
echo "   Removed /etc/systemd/system/netbird-update.service"
echo "   Removed /etc/systemd/system/netbird-update.timer"

echo ""
log_step "Removing update script..."
if [[ -f "$INSTALL_DIR/scripts/update-netbird.sh" ]]; then
    sudo rm -f "$INSTALL_DIR/scripts/update-netbird.sh"
    echo "   Removed $INSTALL_DIR/scripts/update-netbird.sh"
else
    echo "   Update script not found (already removed?)"
fi

echo ""
log_step "Removing config and lock files..."
sudo rm -f "$NETBIRD_AUTOUPDATE_CONF"
echo "   Removed $NETBIRD_AUTOUPDATE_CONF"

if [[ -f /run/netbird-update.lock ]]; then
    sudo rm -f /run/netbird-update.lock
    echo "   Removed /run/netbird-update.lock"
fi

# Final daemon reload
if command -v systemctl >/dev/null 2>&1; then
    sudo systemctl daemon-reload 2>/dev/null || true
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_success "Uninstall complete!"
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