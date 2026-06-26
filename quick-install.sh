#!/usr/bin/env bash

# Quick installer: clones/updates repo and runs deploy-all.sh
# Usage: curl -fsSL https://raw.githubusercontent.com/tolakang/netbird-autoupdate/main/quick-install.sh | sudo bash [INSTALL_DIR]

set -euo pipefail

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Source the shared library
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/lib/common.sh"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  NetBird Auto-Update Quick Installer"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Clone or update the repository
clone_or_update_repo

echo ""

# Run deploy-all.sh with any passed argument
log_step "Running deployment..."
echo ""

if [[ $# -gt 0 ]]; then
    sudo bash "$NETBIRD_AUTOUPDATE_REPO_DIR/scripts/deploy-all.sh" "$@"
else
    sudo bash "$NETBIRD_AUTOUPDATE_REPO_DIR/scripts/deploy-all.sh"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_success "Installation complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Repository location: $NETBIRD_AUTOUPDATE_REPO_DIR"
echo ""
echo "To update in the future, run:"
echo "  sudo bash $NETBIRD_AUTOUPDATE_REPO_DIR/scripts/deploy-all.sh"
echo ""
echo "To uninstall, run:"
echo "  sudo bash $NETBIRD_AUTOUPDATE_REPO_DIR/scripts/uninstall.sh"