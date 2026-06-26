#!/usr/bin/env bash

# Quick installer: clones/updates repo and runs deploy-all.sh
# Usage: curl -fsSL https://raw.githubusercontent.com/tolakang/netbird-autoupdate/main/quick-install.sh | sudo bash [INSTALL_DIR]
#
# This script:
#   1. Clones the repo (or updates if already cloned)
#   2. Runs deploy-all.sh with the specified install dir (or auto-detects)

set -euo pipefail

REPO_URL="https://github.com/tolakang/netbird-autoupdate.git"
REPO_DIR="/opt/netbird-autoupdate-repo"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  NetBird Auto-Update Quick Installer"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Fix git "dubious ownership" error by marking the directory as safe
# This is needed when the repo was created by a different user (e.g., root via sudo)
git config --global --add safe.directory "$REPO_DIR" 2>/dev/null || true

# Clone or update the repository
if [[ -d "$REPO_DIR/.git" ]]; then
    echo "📦 Repository exists at $REPO_DIR"
    echo "   Pulling latest changes..."
    cd "$REPO_DIR"
    sudo git pull origin main
else
    echo "📦 Cloning repository to $REPO_DIR..."
    sudo mkdir -p "$REPO_DIR"
    sudo chown "${SUDO_USER:-$USER}:${SUDO_USER:-$USER}" "$REPO_DIR" 2>/dev/null || true
    git clone "$REPO_URL" "$REPO_DIR"
    # Mark as safe immediately after clone (in case it gets owned by another user later)
    git config --global --add safe.directory "$REPO_DIR"
    cd "$REPO_DIR"
fi

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
echo "  sudo bash $REPO_DIR/scripts/deploy-all.sh"
echo ""
echo "To uninstall, run:"
echo "  sudo bash $REPO_DIR/scripts/uninstall.sh"