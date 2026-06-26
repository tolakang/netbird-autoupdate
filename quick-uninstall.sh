#!/usr/bin/env bash

# Quick uninstaller: removes NetBird auto-update completely
# Usage: curl -fsSL https://raw.githubusercontent.com/tolakang/netbird-autoupdate/main/quick-uninstall.sh | sudo bash [INSTALL_DIR]

set -uo pipefail

REPO_DIR="/opt/netbird-autoupdate-repo"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  NetBird Auto-Update Quick Uninstaller"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# If repo exists locally, use its uninstall.sh
if [[ -f "$REPO_DIR/scripts/uninstall.sh" ]]; then
    echo "Using uninstall script from: $REPO_DIR"
    echo ""
    if [[ $# -gt 0 ]]; then
        sudo bash "$REPO_DIR/scripts/uninstall.sh" "$@"
    else
        sudo bash "$REPO_DIR/scripts/uninstall.sh"
    fi
else
    # Fallback: download and run uninstall.sh
    echo "Local repo not found at $REPO_DIR"
    echo "Downloading uninstall script from GitHub..."
    TEMP_SCRIPT=$(mktemp)
    if curl -fsSL https://raw.githubusercontent.com/tolakang/netbird-autoupdate/main/scripts/uninstall.sh -o "$TEMP_SCRIPT" 2>/dev/null; then
        chmod +x "$TEMP_SCRIPT"
        if [[ $# -gt 0 ]]; then
            sudo bash "$TEMP_SCRIPT" "$@"
        else
            sudo bash "$TEMP_SCRIPT"
        fi
        rm -f "$TEMP_SCRIPT"
    else
        echo "❌ Failed to download uninstall script."
        echo "   Please clone the repo manually and run: sudo ./scripts/uninstall.sh"
        exit 1
    fi
fi