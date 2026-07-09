#!/bin/bash
set -e

# ── Environment check (L4T version, disk, memory) ──────────────────────────
source "$(dirname "$(realpath "$0")")/../utils.sh"
check_base_env "$(dirname "$(realpath "$0")")/config.yaml"

SCRIPT_DIR="$(cd "$(dirname "$(realpath "$0")")" && pwd)"
IMAGE_NAME="locateanything:latest"

echo "=== LocateAnything-3B Web UI — Init (Docker) ==="

# Check if Docker is available
if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: docker not found. Install Docker first."
    exit 1
fi

# Build the image if it doesn't exist (idempotent — skips on subsequent runs)
if docker images "$IMAGE_NAME" --format "{{.Repository}}" 2>/dev/null | grep -q "locateanything"; then
    echo "Docker image '$IMAGE_NAME' already built."
else
    echo "Building Docker image '$IMAGE_NAME'..."
    echo "  First build downloads ~5GB of PyTorch + CUDA wheels (~30 min)."
    echo "  Build is cache-resumable — if it fails, re-run to resume."
    echo ""
    docker buildx build --network host --progress=plain -t "$IMAGE_NAME" "$SCRIPT_DIR"
    echo ""
    echo "Image built successfully."
fi

# Create the model cache volume (persists the 7.3GB model across restarts)
if ! docker volume inspect locateanything-models >/dev/null 2>&1; then
    echo "Creating model cache volume 'locateanything-models'..."
    docker volume create locateanything-models >/dev/null
fi

echo ""
echo "=== Init complete! ==="
echo "Run:   reComputer run locateanything"
echo "Open:  http://<jetson-ip>:7860"
echo ""
echo "Note: First 'run' downloads the 7.3GB model into the volume (~15 min)."
