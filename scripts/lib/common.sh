#!/usr/bin/env bash
# Shared library for netbird-autoupdate scripts
# This file is sourced by other scripts - not meant to be executed directly.

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "ERROR: This is a library file. Source it from other scripts." >&2
    exit 1
fi

##############################################
# Configuration
##############################################

# Repository location
NETBIRD_AUTOUPDATE_REPO_URL="https://github.com/tolakang/netbird-autoupdate.git"
NETBIRD_AUTOUPDATE_REPO_DIR="/opt/netbird-autoupdate-repo"

# Config file for persistent settings
NETBIRD_AUTOUPDATE_CONF="/etc/netbird-autoupdate.conf"

# Standard NetBird install paths to search
NETBIRD_DEFAULT_PATHS=(
    "/opt/netbird"
    "/srv/netbird"
    "/home/netbird"
    "/var/lib/netbird"
    "/etc/netbird"
    "/usr/local/netbird"
)

##############################################
# Functions
##############################################

# Print colored output (auto-detects if terminal supports it)
log_info() { echo "ℹ️  $*"; }
log_success() { echo "✅ $*"; }
log_warn() { echo "⚠️  $*"; }
log_error() { echo "❌ $*"; }
log_step() { echo "📦 $*"; }

# Check if a command exists
require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        log_error "Required command not found: $1"
        return 1
    fi
}

# Fix git "dubious ownership" error for a directory
# Usage: fix_git_ownership "/path/to/repo"
fix_git_ownership() {
    local repo_dir="$1"

    # Try multiple approaches to set safe.directory
    # 1. Current user (typically root when using sudo)
    git config --global --add safe.directory "$repo_dir" 2>/dev/null || true

    # 2. Root explicitly
    if [[ -d /root ]]; then
        sudo git config --global --add safe.directory "$repo_dir" 2>/dev/null || true
    fi

    # 3. The actual invoking user (when run via sudo)
    if [[ -n "${SUDO_USER:-}" ]] && [[ "$SUDO_USER" != "root" ]]; then
        local real_home
        real_home=$(getent passwd "$SUDO_USER" | cut -d: -f6 2>/dev/null)
        if [[ -n "$real_home" ]]; then
            sudo -u "$SUDO_USER" git config --global --add safe.directory "$repo_dir" 2>/dev/null || true
        fi
    fi
}

# Run git pull with safe.directory override (works regardless of ownership)
# Usage: safe_git_pull "/path/to/repo" "main"
safe_git_pull() {
    local repo_dir="$1"
    local branch="${2:-main}"
    sudo git -c safe.directory="$repo_dir" -c safe.directory='*' \
        -C "$repo_dir" pull origin "$branch"
}

# Build the list of search paths for NetBird detection
_build_search_paths() {
    local -a paths=("${NETBIRD_DEFAULT_PATHS[@]}")

    # Add SUDO_USER's home directory paths
    if [[ -n "${SUDO_USER:-}" ]]; then
        local user_home
        user_home=$(getent passwd "$SUDO_USER" | cut -d: -f6 2>/dev/null)
        if [[ -n "$user_home" ]]; then
            paths+=(
                "$user_home/netbird"
                "$user_home/netbird-host"
                "$user_home/netbird-selfhost"
            )
        fi
    fi

    # Add all /home/* directories
    for user_dir in /home/*/; do
        [[ -d "$user_dir" ]] || continue
        paths+=(
            "${user_dir}netbird"
            "${user_dir}netbird-host"
            "${user_dir}netbird-selfhost"
        )
    done

    echo "${paths[@]}"
}

# Detect NetBird installation directory
# Usage: detect_netbird_dir <check_type>
#   check_type: "compose" (checks for docker-compose.yml) or "script" (checks for update-netbird.sh)
detect_netbird_dir() {
    local check_type="${1:-compose}"
    local search_paths
    search_paths=$(_build_search_paths)

    for candidate in $search_paths; do
        local check_file
        if [[ "$check_type" == "compose" ]]; then
            check_file="$candidate/docker-compose.yml"
        else
            check_file="$candidate/scripts/update-netbird.sh"
        fi

        if [[ -f "$check_file" ]]; then
            # For compose, verify it's a NetBird compose file
            if [[ "$check_type" == "compose" ]]; then
                if grep -q "netbird-server\|netbirdio/" "$check_file" 2>/dev/null; then
                    echo "$candidate"
                    return 0
                fi
            else
                # For script check, just verify the script exists
                echo "$candidate"
                return 0
            fi
        fi
    done

    return 1
}

# Resolve install directory: argument > env var > config file > auto-detect
# Usage: resolve_install_dir "$@"
#   Sets global INSTALL_DIR
resolve_install_dir() {
    INSTALL_DIR="${1:-${INSTALL_DIR:-}}"

    # Load from config if still empty
    if [[ -z "$INSTALL_DIR" ]] && [[ -f "$NETBIRD_AUTOUPDATE_CONF" ]]; then
        # shellcheck disable=SC1090
        source "$NETBIRD_AUTOUPDATE_CONF"
        INSTALL_DIR="${INSTALL_DIR:-}"
    fi

    # Auto-detect if still empty
    if [[ -z "$INSTALL_DIR" ]]; then
        log_info "Auto-detecting NetBird installation directory..."
        if INSTALL_DIR=$(detect_netbird_dir compose); then
            log_success "Found NetBird installation at: $INSTALL_DIR"
        else
            return 1
        fi
    else
        log_info "Using install directory: $INSTALL_DIR"
    fi

    export INSTALL_DIR
}

# Validate that a directory is a valid NetBird installation
# Usage: validate_netbird_install "$INSTALL_DIR"
validate_netbird_install() {
    local dir="$1"

    if [[ ! -d "$dir" ]]; then
        log_error "Directory does not exist: $dir"
        return 1
    fi

    if [[ ! -f "$dir/docker-compose.yml" ]]; then
        log_error "docker-compose.yml not found in: $dir"
        return 1
    fi

    if ! grep -q "netbird-server\|netbirdio/" "$dir/docker-compose.yml" 2>/dev/null; then
        log_warn "docker-compose.yml does not appear to contain NetBird services"
        return 2  # Warning, not error
    fi

    return 0
}

# Save install directory to config file
# Usage: save_install_dir "$INSTALL_DIR"
save_install_dir() {
    local dir="$1"
    echo "INSTALL_DIR=\"$dir\"" | sudo tee "$NETBIRD_AUTOUPDATE_CONF" >/dev/null
}

# Reload systemd and enable the timer
# Usage: enable_netbird_timer
enable_netbird_timer() {
    if ! command -v systemctl >/dev/null 2>&1; then
        log_warn "systemctl not available, skipping service management"
        return 0
    fi

    sudo systemctl daemon-reload
    sudo systemctl enable --now netbird-update.timer
}

# Stop and disable the timer
# Usage: disable_netbird_timer
disable_netbird_timer() {
    if ! command -v systemctl >/dev/null 2>&1; then
        return 0
    fi

    sudo systemctl stop netbird-update.timer 2>/dev/null || true
    sudo systemctl stop netbird-update.service 2>/dev/null || true
    sudo systemctl disable netbird-update.timer 2>/dev/null || true
    sudo systemctl daemon-reload
    sudo systemctl reset-failed netbird-update.service netbird-update.timer 2>/dev/null || true
}

# Clone or update the repository
# Usage: clone_or_update_repo
clone_or_update_repo() {
    if [[ -d "$NETBIRD_AUTOUPDATE_REPO_DIR/.git" ]]; then
        log_step "Repository exists at $NETBIRD_AUTOUPDATE_REPO_DIR"
        log_info "Pulling latest changes..."
        fix_git_ownership "$NETBIRD_AUTOUPDATE_REPO_DIR"
        safe_git_pull "$NETBIRD_AUTOUPDATE_REPO_DIR" main
    else
        log_step "Cloning repository to $NETBIRD_AUTOUPDATE_REPO_DIR..."
        sudo mkdir -p "$NETBIRD_AUTOUPDATE_REPO_DIR"
        sudo chown "${SUDO_USER:-$USER}:${SUDO_USER:-$USER}" "$NETBIRD_AUTOUPDATE_REPO_DIR" 2>/dev/null || true
        git -c safe.directory='*' clone "$NETBIRD_AUTOUPDATE_REPO_URL" "$NETBIRD_AUTOUPDATE_REPO_DIR"
        fix_git_ownership "$NETBIRD_AUTOUPDATE_REPO_DIR"
    fi
}

# Confirm action with user
# Usage: confirm "message"
confirm() {
    local message="${1:-Continue?}"
    local response
    read -rp "$message [y/N] " response
    [[ "$response" =~ ^[Yy]$ ]]
}