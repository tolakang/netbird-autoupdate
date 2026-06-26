#!/usr/bin/env bash

# Uninstall NetBird auto-update system
# Removes all files, systemd units, and configuration created by deploy-all.sh
#
# Usage: sudo ./scripts/uninstall.sh [INSTALL_DIR]
#   INSTALL_DIR: NetBird installation directory (auto-detects if not specified)

set -uo pipefail

# Get script directory and source shared library
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/common.sh"

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
    if INSTALL_DIR=$(detect_netbird_dir script); then
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
disable_netbird_timer

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