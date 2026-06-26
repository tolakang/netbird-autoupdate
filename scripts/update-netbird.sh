#!/usr/bin/env bash
set -Eeuo pipefail

##############################################
# NetBird Self-Hosted Auto Update
# Version: 1.3
##############################################

# Allow override via environment variable, default to standard /opt/netbird
COMPOSE_DIR="${COMPOSE_DIR:-/opt/netbird}"
COMPOSE_FILE="${COMPOSE_FILE:-${COMPOSE_DIR}/docker-compose.yml}"
BACKUP_DIR="${BACKUP_DIR:-${COMPOSE_DIR}/backups}"

# Services to update (override via SERVICES env var, space-separated)
if [[ -n "${SERVICES:-}" ]]; then
    IFS=' ' read -r -a SERVICES <<< "$SERVICES"
else
    SERVICES=(netbird-server dashboard proxy)
fi

# Configuration files to backup (override via BACKUP_FILES env var)
if [[ -n "${BACKUP_FILES:-}" ]]; then
    IFS=' ' read -r -a BACKUP_FILES <<< "$BACKUP_FILES"
else
    BACKUP_FILES=(docker-compose.yml config.yaml dashboard.env proxy.env)
fi

# Make variables readonly after potential assignment
readonly COMPOSE_DIR COMPOSE_FILE BACKUP_DIR SERVICES BACKUP_FILES BACKUP_RETENTION
BACKUP_RETENTION="${BACKUP_RETENTION:-30}"

# Validate compose file exists
if [[ ! -f "$COMPOSE_FILE" ]]; then
    echo "[$(date '+%F %T')] ERROR: Docker compose file not found at: $COMPOSE_FILE"
    echo "Set COMPOSE_DIR environment variable to your NetBird installation directory."
    exit 1
fi

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Logging function
log() {
    echo "[$(date '+%F %T')] $*"
}

# Error trap
trap 'log "ERROR: Script failed on line ${LINENO}"; exit 1' ERR

# Prevent concurrent executions using file lock
exec 9>/run/netbird-update.lock
flock -n 9 || {
    log "Another NetBird update is already running. Exiting."
    exit 0
}

log "=================================================="
log "Starting NetBird update process"
log "  Install dir:   $COMPOSE_DIR"
log "  Services:      ${SERVICES[*]}"
log "  Retention:     $BACKUP_RETENTION backups"

# Verify Docker is installed and running
if ! command -v docker >/dev/null 2>&1; then
    log "ERROR: docker command not found. Please install Docker."
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    log "ERROR: Docker daemon is not running or inaccessible."
    exit 1
fi

# Current image IDs before pulling
log "Checking current image versions..."
OLD_IDS=()
for svc in "${SERVICES[@]}"; do
    OLD_IDS+=("$(docker compose -f "$COMPOSE_FILE" images -q "$svc" 2>/dev/null || echo "")")
done

# Pull latest images for the defined services
log "Pulling latest images..."
docker compose -f "$COMPOSE_FILE" pull "${SERVICES[@]}"

# Image IDs after pulling
NEW_IDS=()
for svc in "${SERVICES[@]}"; do
    NEW_IDS+=("$(docker compose -f "$COMPOSE_FILE" images -q "$svc" 2>/dev/null || echo "")")
done

# Check if any image has changed
UPDATED=false
CHANGED_SERVICES=()
for i in "${!SERVICES[@]}"; do
    if [[ "${OLD_IDS[$i]}" != "${NEW_IDS[$i]}" ]] && [[ -n "${NEW_IDS[$i]}" ]]; then
        UPDATED=true
        CHANGED_SERVICES+=("${SERVICES[$i]}")
        log "New version detected for service: ${SERVICES[$i]}"
    fi
done

if [[ "$UPDATED" != "true" ]]; then
    log "No new NetBird images found. System is up to date."
    exit 0
fi

log "New images detected for: ${CHANGED_SERVICES[*]}"

# Stop netbird-server for consistent backup
log "Stopping netbird-server for backup..."
docker compose -f "$COMPOSE_FILE" stop netbird-server

# Backup configuration files
BACKUP_TIMESTAMP=$(date +%Y%m%d-%H%M%S)
for file in "${BACKUP_FILES[@]}"; do
    src="${COMPOSE_DIR}/${file}"
    [[ -f "$src" ]] || continue

    # Generate a backup filename preserving the extension
    case "$file" in
        *.yml)  dest="${BACKUP_DIR}/${file%.yml}-${BACKUP_TIMESTAMP}.yml" ;;
        *.yaml) dest="${BACKUP_DIR}/${file%.yaml}-${BACKUP_TIMESTAMP}.yaml" ;;
        *.env)  dest="${BACKUP_DIR}/${file}-${BACKUP_TIMESTAMP}.env" ;;
        *)      dest="${BACKUP_DIR}/${file}-${BACKUP_TIMESTAMP}" ;;
    esac

    cp "$src" "$dest"
    log "Backed up ${file}"
done

# Backup management data directory
log "Backing up management data..."
if docker compose -f "$COMPOSE_FILE" cp netbird-server:/var/lib/netbird/ "${BACKUP_DIR}/netbird-data-${BACKUP_TIMESTAMP}/" 2>/dev/null; then
    log "Management data backed up"
else
    log "Management data backup skipped (container may not be running or data not present)"
fi

# Start netbird-server again
log "Starting netbird-server..."
docker compose -f "$COMPOSE_FILE" start netbird-server

log "Configuration and data backups created."

# Recreate only the services that have updated images
log "Recreating services with new images: ${CHANGED_SERVICES[*]}"
docker compose -f "$COMPOSE_FILE" up -d --force-recreate "${CHANGED_SERVICES[@]}"

# Clean up dangling images to save space
log "Cleaning up dangling images..."
docker image prune -f

# Keep only the newest N backups for each file type and data backups
log "Maintaining backup rotation (keeping newest $BACKUP_RETENTION)..."

# Rotate config file backups (keep newest N per prefix)
for prefix in docker-compose config dashboard proxy; do
    mapfile -t backups < <(
        ls -1t "$BACKUP_DIR/$prefix-"*.yml \
              "$BACKUP_DIR/$prefix-"*.yaml \
              "$BACKUP_DIR/$prefix-"*.env 2>/dev/null
    )
    if [[ ${#backups[@]} -gt $BACKUP_RETENTION ]]; then
        printf '%s\0' "${backups[@]:$BACKUP_RETENTION}" | xargs -0 -r rm -f
    fi
done

# Rotate data backups (directories, keep newest N)
mapfile -t data_backups < <(ls -1dt "$BACKUP_DIR"/netbird-data-*/ 2>/dev/null)
if [[ ${#data_backups[@]} -gt $BACKUP_RETENTION ]]; then
    printf '%s\0' "${data_backups[@]:$BACKUP_RETENTION}" | xargs -0 -r rm -rf
fi

log "NetBird updated successfully."
log "Finished."
log "=================================================="