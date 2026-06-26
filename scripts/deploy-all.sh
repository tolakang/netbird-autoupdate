#!/usr/bin/env bash

# Auto-deploy NetBird auto-update system from repository
# Usage: sudo ./scripts/deploy-all.sh [INSTALL_DIR]
#   INSTALL_DIR: Directory where NetBird is installed (default: /opt/netbird)

set -euo pipefail

# Allow custom install directory as argument or env variable
INSTALL_DIR="${1:-${INSTALL_DIR:-/opt/netbird}}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "Deploying NetBird auto-update system from: $REPO_ROOT"
echo "Install directory: $INSTALL_DIR"

# Validate install directory exists and contains docker-compose.yml
if [[ ! -d "$INSTALL_DIR" ]]; then
    echo "❌ ERROR: Install directory does not exist: $INSTALL_DIR"
    echo "   Run the official NetBird quick-start script first to create it."
    exit 1
fi

if [[ ! -f "$INSTALL_DIR/docker-compose.yml" ]]; then
    echo "❌ ERROR: docker-compose.yml not found in: $INSTALL_DIR"
    echo "   Ensure NetBird is installed in this directory."
    exit 1
fi

# Ensure destination directories exist
sudo mkdir -p "$INSTALL_DIR/scripts"
sudo mkdir -p /etc/systemd/system

# Copy update script
echo "Installing update script..."
sudo cp "$REPO_ROOT/scripts/update-netbird.sh" "$INSTALL_DIR/scripts/update-netbird.sh"
sudo chmod +x "$INSTALL_DIR/scripts/update-netbird.sh"

# Copy systemd unit files with customized paths
echo "Installing systemd units..."
sudo cp "$REPO_ROOT/systemd/netbird-update.service" /etc/systemd/system/netbird-update.service
sudo cp "$REPO_ROOT/systemd/netbird-update.timer"   /etc/systemd/system/netbird-update.timer

# Patch the service file to use the correct install directory
sudo sed -i "s|/opt/netbird|$INSTALL_DIR|g" /etc/systemd/system/netbird-update.service

# Reload systemd to recognize new units
sudo systemctl daemon-reload

# Enable and start the timer (service will run on schedule)
sudo systemctl enable --now netbird-update.timer

echo "✅ NetBird auto-update system deployed successfully."
echo "   Update script: $INSTALL_DIR/scripts/update-netbird.sh"
echo "   NetBird home:  $INSTALL_DIR"
echo "   Systemd units: /etc/systemd/system/"
echo "   Timer enabled: weekly on Sunday 03:00 (with 15min randomization)"