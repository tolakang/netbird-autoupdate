#!/usr/bin/env bash

# Quick uninstaller: removes NetBird auto-update completely
# Usage: curl -fsSL https://raw.githubusercontent.com/tolakang/netbird-autoupdate/main/quick-uninstall.sh | sudo bash [INSTALL_DIR]

set -uo pipefail

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Source the shared library
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/lib/common.sh"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  NetBird Auto-Update Quick Uninstaller"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# If repo exists locally, use its uninstall.sh
if [[ -f "$NETBIRD_AUTOUPDATE_REPO_DIR/scripts/uninstall.sh" ]]; then
    log_info "Using uninstall script from: $NETBIRD_AUTOUPDATE_REPO_DIR"
    echo ""
    if [[ $# -gt 0 ]]; then
        sudo bash "$NETBIRD_AUTOUPDATE_REPO_DIR/scripts/uninstall.sh" "$@"
    else
        sudo bash "$NETBIRD_AUTOUPDATE_REPO_DIR/scripts/uninstall.sh"
    fi
else
    # Fallback: download and run uninstall.sh
    log_warn "Local repo not found at $NETBIRD_AUTOUPDATE_REPO_DIR"
    log_info "Downloading uninstall script from GitHub..."

    local_temp_script=$(mktemp)
    if curl -fsSL "${NETBIRD_AUTOUPDATE_REPO_URL/raw/main/scripts/uninstall.sh}" -o "$local_temp_script" 2>/dev/null; then
        chmod +x "$local_temp_script"
        if [[ $# -gt 0 ]]; then
            sudo bash "$local_temp_script" "$@"
        else
            sudo bash "$local_temp_script"
        fi
        rm -f "$local_temp_script"
    else
        log_error "Failed to download uninstall script."
        echo "Please clone the repo manually and run: sudo ./scripts/uninstall.sh"
        exit 1
    fi
fi