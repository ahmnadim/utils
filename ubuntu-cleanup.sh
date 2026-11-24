# mkdir -p ~/bin
# nano ~/bin/ubuntu-cleanup.sh

# Make it executable
# chmod +x ~/bin/ubuntu-cleanup.sh

# 4. Run whenever necessary
# ~/bin/ubuntu-cleanup.sh

# Create a shorter command
# nano ~/.bashrc
# Add this at the bottom:
# alias cleanup='~/bin/ubuntu-cleanup.sh'
# Reload:
# source ~/.bashrc
# Now you can simply execute:
# cleanup

#!/usr/bin/env bash

set -Eeuo pipefail

# ==========================================
# Ubuntu VM Cleanup Utility
# ==========================================

KEEP_JOURNAL_DAYS=7

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

confirm() {
    read -r -p "$1 [y/N]: " answer
    [[ "$answer" =~ ^[Yy]$ ]]
}

show_disk_usage() {
    echo
    echo "========== DISK USAGE =========="
    df -h /
    echo
    echo "========== INODE USAGE =========="
    df -i /
    echo
}

echo "======================================"
echo "       UBUNTU VM CLEANUP TOOL"
echo "======================================"

show_disk_usage

# ------------------------------------------
# 1. APT cleanup
# ------------------------------------------

info "Cleaning APT cache..."

sudo apt clean
sudo apt autoclean
sudo apt autoremove --purge -y

# ------------------------------------------
# 2. System journal cleanup
# ------------------------------------------

info "Cleaning old system journal logs..."

sudo journalctl --vacuum-time="${KEEP_JOURNAL_DAYS}d"

# ------------------------------------------
# 3. Snap old revisions
# ------------------------------------------

if command -v snap >/dev/null 2>&1; then

    info "Checking old Snap revisions..."

    while read -r package revision; do

        [[ -z "${package:-}" ]] && continue

        info "Removing old Snap revision: $package ($revision)"

        sudo snap remove "$package" \
            --revision="$revision" \
            --purge

    done < <(
        snap list --all | awk '$NF == "disabled" {print $1, $3}'
    )

else
    info "Snap is not installed. Skipping."
fi

# ------------------------------------------
# 4. Docker cleanup
# ------------------------------------------

if command -v docker >/dev/null 2>&1 &&
   docker info >/dev/null 2>&1; then

    echo
    echo "========== DOCKER STORAGE =========="

    docker system df

    if confirm "Remove unused Docker build cache?"; then
        info "Cleaning Docker build cache..."
        docker builder prune -af
    fi

    if confirm "Remove unused Docker images?"; then
        warn "Images not associated with containers will be removed."
        docker image prune -af
    fi

    echo
    info "Docker cleanup completed."

    echo
    echo "========== DOCKER STORAGE AFTER =========="

    docker system df

else
    warn "Docker is unavailable or not running. Skipping."
fi

# ------------------------------------------
# 5. Final report
# ------------------------------------------

echo
info "Cleanup completed!"

show_disk_usage

# ------------------------------------------
# 6. Show largest directories
# ------------------------------------------

echo "========== LARGEST ROOT DIRECTORIES =========="

sudo du -xhd1 / 2>/dev/null | sort -h

echo
info "All done!"
