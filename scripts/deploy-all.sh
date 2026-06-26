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

# Get script directory and source shared library
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/common.sh"

REPO_ROOT="$SCRIPT_DIR/.."

# Fix git ownership for this repo
fix_git_ownership "$REPO_ROOT"

log_step "Deploying NetBird auto-update system from: $REPO_ROOT"

# Resolve install directory
if ! resolve_install_dir "$@"; then
    log_error "Could not auto-detect NetBird installation."
    echo ""
    echo "Please specify the directory manually:"
    echo "  sudo ./scripts/deploy-all.sh /path/to/netbird"
    echo ""
    echo "Common locations searched:"
    echo "  ${NETBIRD_DEFAULT_PATHS[*]}, /home/*/netbird, etc."
    exit 1
fi

# Validate the install directory
validate_result=0
validate_netbird_install "$INSTALL_DIR" || validate_result=$?

if [[ $validate_result -eq 1 ]]; then
    exit 1
elif [[ $validate_result -eq 2 ]]; then
    echo "   Found at: $INSTALL_DIR"
    if ! confirm "   Continue anyway?"; then
        echo "Aborted."
        exit 1
    fi
fi

# Save the directory for future runs
save_install_dir "$INSTALL_DIR"

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
log_step "Installing update script..."
sudo cp "$REPO_ROOT/scripts/update-netbird.sh" "$INSTALL_DIR/scripts/update-netbird.sh"
sudo chmod +x "$INSTALL_DIR/scripts/update-netbird.sh"

# Copy systemd unit files
log_step "Installing systemd units..."
sudo cp "$REPO_ROOT/systemd/netbird-update.service" /etc/systemd/system/netbird-update.service
sudo cp "$REPO_ROOT/systemd/netbird-update.timer"   /etc/systemd/system/netbird-update.timer

# Patch the service file to use the correct install directory
sudo sed -i "s|/opt/netbird|$INSTALL_DIR|g" /etc/systemd/system/netbird-update.service

# Reload systemd and enable timer
enable_netbird_timer

echo ""
log_success "NetBird auto-update system deployed successfully!"
echo ""
echo "   📍 Update script:  $INSTALL_DIR/scripts/update-netbird.sh"
echo "   📍 NetBird home:   $INSTALL_DIR"
echo "   📍 Systemd units:  /etc/systemd/system/"
echo "   ⏰ Timer enabled:  weekly on Sunday 03:00 (with 15min randomization)"
echo "   💾 Config saved:   $NETBIRD_AUTOUPDATE_CONF"
echo ""
echo "Useful commands:"
echo "   systemctl list-timers netbird-update.timer    # View schedule"
echo "   sudo systemctl start netbird-update.service  # Run update now"
echo "   journalctl -u netbird-update.service -f      # View logs"