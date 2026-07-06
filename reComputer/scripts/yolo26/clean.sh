#!/bin/bash
set -e

IMAGE_VERSION="8.4.54"
SLIM_IMAGE="ultralytics/ultralytics:${IMAGE_VERSION}-jetson-slim"
SCRIPT_DIR="$(cd "$(dirname "$(realpath "$0")")" && pwd)"

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --slim    Clean only the slim image (not the fat image).
  --all     Clean both the slim image and the fat image.
  --fat     Clean only the fat image (default if no flag given).
  -h, --help  Show this help message.

Examples:
  $0                  # Clean fat image (default behavior)
  $0 --slim           # Clean slim image
  $0 --all            # Clean both fat and slim images
EOF
}

CLEAN_FAT=false
CLEAN_SLIM=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --slim) CLEAN_SLIM=true; shift ;;
        --all)  CLEAN_FAT=true; CLEAN_SLIM=true; shift ;;
        --fat)  CLEAN_FAT=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1"; usage; exit 1 ;;
    esac
done

# Default: clean fat image if no flag given
if ! $CLEAN_FAT && ! $CLEAN_SLIM; then
    CLEAN_FAT=true
fi

get_l4t_release() {
    if [ -f /etc/nv_tegra_release ]; then
        head -n 1 /etc/nv_tegra_release | grep -o 'R[0-9]*' | head -1 | cut -dR -f2
    fi
}

stop_and_remove() {
    local img="$1"
    echo "--- Cleaning image: $img ---"
    if sudo docker ps -q --filter "ancestor=$img" | grep -q .; then
        echo "Stopping containers using $img..."
        sudo docker ps -q --filter "ancestor=$img" | xargs -r sudo docker stop
    fi
    if sudo docker image inspect "$img" >/dev/null 2>&1; then
        sudo docker rmi "$img" && echo "Removed: $img" || echo "Failed to remove: $img"
    else
        echo "Image not found: $img"
    fi
}

# === Slim ===
if $CLEAN_SLIM; then
    echo "Stopping yolo26_slim container..."
    sudo docker stop yolo26_slim 2>/dev/null || true
    stop_and_remove "$SLIM_IMAGE"
fi

# === Fat image ===
if $CLEAN_FAT; then
    L4T_RELEASE=$(get_l4t_release)
    case "$L4T_RELEASE" in
        35) FAT_IMAGE="ultralytics/ultralytics:${IMAGE_VERSION}-jetson-jetpack5" ;;
        36) FAT_IMAGE="ultralytics/ultralytics:${IMAGE_VERSION}-jetson-jetpack6" ;;
        38) FAT_IMAGE="ultralytics/ultralytics:${IMAGE_VERSION}-nvidia-arm64" ;;
        *)  echo "Unable to detect JetPack version for fat image cleanup."; exit 0 ;;
    esac
    stop_and_remove "$FAT_IMAGE"
fi

echo "Done."
