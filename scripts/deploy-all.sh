#!/usr/bin/env bash

# Auto-deploy NetBird auto-update system from repository
# Installs update script to /opt/netbird/scripts/ and systemd units to /etc/systemd/system/

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "Deploying NetBird auto-update system from: $REPO_ROOT"

# Ensure destination directories exist
sudo mkdir -p /opt/netbird/scripts
sudo mkdir -p /etc/systemd/system

# Copy update script
echo "Installing update script..."
sudo cp "$REPO_ROOT/scripts/update-netbird.sh" /opt/netbird/scripts/update-netbird.sh
sudo chmod +x /opt/netbird/scripts/update-netbird.sh

# Copy systemd unit files to /etc/systemd/system/ (where systemd reads them)
echo "Installing systemd units..."
sudo cp "$REPO_ROOT/systemd/netbird-update.service" /etc/systemd/system/
sudo cp "$REPO_ROOT/systemd/netbird-update.timer"   /etc/systemd/system/

# Reload systemd to recognize new units
sudo systemctl daemon-reload

# Enable and start the timer (service will run on schedule)
sudo systemctl enable --now netbird-update.timer

echo "✅ NetBird auto-update system deployed successfully."
echo "   Update script: /opt/netbird/scripts/update-netbird.sh"
echo "   Systemd units: /etc/systemd/system/"
echo "   Timer enabled: weekly on Sunday 03:00 (with 15min randomization)"