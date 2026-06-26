#!/usr/bin/env bash

# Quick installer: clones/updates repo and runs deploy-all.sh
# Usage: curl -fsSL https://raw.githubusercontent.com/tolakang/netbird-autoupdate/main/quick-install.sh | sudo bash [INSTALL_DIR]
#
# This script is self-contained (no external dependencies) so it can be piped
# via curl directly to bash. It clones the repo to a known location and runs
# the deploy-all.sh from there, which has access to the shared library.

set -euo pipefail

REPO_URL="https://github.com/tolakang/netbird-autoupdate.git"
REPO_DIR="/opt/netbird-autoupdate-repo"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  NetBird Auto-Update Quick Installer"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Fix git "dubious ownership" for the repo directory
# This handles the case where the repo was cloned by a different user (root vs current user)
git config --global --add safe.directory "$REPO_DIR" 2>/dev/null || true
sudo git config --global --add safe.directory "$REPO_DIR" 2>/dev/null || true
if [[ -n "${SUDO_USER:-}" ]] && [[ "$SUDO_USER" != "root" ]]; then
    REAL_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6 2>/dev/null)
    if [[ -n "$REAL_HOME" ]]; then
        sudo -u "$SUDO_USER" git config --global --add safe.directory "$REPO_DIR" 2>/dev/null || true
    fi
fi

# Clone or update the repository
if [[ -d "$REPO_DIR/.git" ]]; then
    echo "📦 Repository exists at $REPO_DIR"
    echo "   Pulling latest changes..."
    # Use git -c to override safe.directory on this specific command (most reliable)
    sudo git -c safe.directory="$REPO_DIR" -c safe.directory='*' \
        -C "$REPO_DIR" pull origin main
else
    echo "📦 Cloning repository to $REPO_DIR..."
    sudo mkdir -p "$REPO_DIR"
    sudo chown "${SUDO_USER:-$USER}:${SUDO_USER:-$USER}" "$REPO_DIR" 2>/dev/null || true
    git -c safe.directory='*' clone "$REPO_URL" "$REPO_DIR"
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