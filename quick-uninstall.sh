#!/usr/bin/env bash

# Quick uninstaller: removes NetBird auto-update completely
# Usage: curl -fsSL https://raw.githubusercontent.com/tolakang/netbird-autoupdate/main/quick-uninstall.sh | sudo bash [INSTALL_DIR]
#
# Self-contained script for piping via curl. Tries to use the local repo's
# uninstall.sh first; falls back to downloading from GitHub.

set -uo pipefail

REPO_DIR="/opt/netbird-autoupdate-repo"
RAW_URL="https://raw.githubusercontent.com/tolakang/netbird-autoupdate/main"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  NetBird Auto-Update Quick Uninstaller"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# If repo exists locally, use its uninstall.sh
if [[ -f "$REPO_DIR/scripts/uninstall.sh" ]]; then
    echo "ℹ️  Using uninstall script from: $REPO_DIR"
    echo ""
    if [[ $# -gt 0 ]]; then
        sudo bash "$REPO_DIR/scripts/uninstall.sh" "$@"
    else
        sudo bash "$REPO_DIR/scripts/uninstall.sh"
    fi
else
    # Fallback: download uninstall.sh directly and run it
    echo "⚠️  Local repo not found at $REPO_DIR"
    echo "ℹ️  Downloading uninstall script from GitHub..."

    TEMP_SCRIPT=$(mktemp)
    if curl -fsSL "$RAW_URL/scripts/uninstall.sh" -o "$TEMP_SCRIPT" 2>/dev/null; then
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