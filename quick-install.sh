#!/usr/bin/env bash

# Quick installer: clones/updates repo and runs deploy-all.sh
# Usage: curl -fsSL https://raw.githubusercontent.com/tolakang/netbird-autoupdate/main/quick-install.sh | sudo bash -s -- [INSTALL_DIR]
#
# Self-contained script for piping via curl. Always clones a fresh copy of the
# repository to ensure the latest code is used (avoids stale local repos).

set -euo pipefail

REPO_URL="https://github.com/tolakang/netbird-autoupdate.git"
REPO_DIR="/opt/netbird-autoupdate-repo"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  NetBird Auto-Update Quick Installer"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Fix git "dubious ownership" for the repo directory (handles multiple user configs)
git config --global --add safe.directory "$REPO_DIR" 2>/dev/null || true
sudo git config --global --add safe.directory "$REPO_DIR" 2>/dev/null || true
if [[ -n "${SUDO_USER:-}" ]] && [[ "$SUDO_USER" != "root" ]]; then
    REAL_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6 2>/dev/null || true)
    if [[ -n "$REAL_HOME" ]]; then
        sudo -u "$SUDO_USER" git config --global --add safe.directory "$REPO_DIR" 2>/dev/null || true
    fi
fi

# Always re-clone to ensure fresh code
if [[ -d "$REPO_DIR/.git" ]]; then
    echo "📦 Removing old repository at $REPO_DIR..."
    sudo rm -rf "$REPO_DIR"
fi

echo "📦 Cloning fresh repository to $REPO_DIR..."
sudo mkdir -p "$REPO_DIR"
sudo chown "${SUDO_USER:-$USER}:${SUDO_USER:-$USER}" "$REPO_DIR" 2>/dev/null || true
git -c safe.directory='*' clone "$REPO_URL" "$REPO_DIR"

echo ""

# Run deploy-all.sh with any passed argument
echo "🚀 Running deployment..."
echo ""

if [[ $# -gt 0 ]]; then
    sudo bash "$REPO_DIR/scripts/deploy-all.sh" "$@"
else
    sudo bash "$REPO_DIR/scripts/deploy-all.sh"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Installation complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Repository location: $REPO_DIR"
echo ""
echo "To update in the future, run:"
echo "  curl -fsSL https://raw.githubusercontent.com/tolakang/netbird-autoupdate/main/quick-install.sh | sudo bash"
echo ""
echo "To uninstall, run:"
echo "  curl -fsSL https://raw.githubusercontent.com/tolakang/netbird-autoupdate/main/quick-uninstall.sh | sudo bash"