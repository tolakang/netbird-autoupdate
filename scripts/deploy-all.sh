#!/usr/bin/env bash

# Auto-deploy NetBird auto-update system from repository
# Copies systemd unit files to the correct locations and enables the timer.

set -euo pipefail

# Ensure destination directories exist
sudo mkdir -p /opt/netbird/systemd

# Copy unit files from the repository to the target location
sudo cp "$(dirname "$0")/../systemd/netbird-update.service" /opt/netbird/systemd/
sudo cp "$(dirname "$0")/../systemd/netbird-update.timer"   /opt/netbird/systemd/

# Reload systemd to recognize new units
sudo systemctl daemon-reload

# Enable and start the timer (service will run on schedule)
sudo systemctl enable --now netbird-update.timer

echo "NetBird auto-update system deployed successfully."
