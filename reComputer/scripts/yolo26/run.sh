#!/bin/bash
set -e

IMAGE_NAME="yolo26:latest"
SCRIPT_DIR="$(cd "$(dirname "$(realpath "$0")")" && pwd)"
MODEL_URL="https://github.com/ultralytics/assets/releases/download/v8.4.0/yolo26n.pt"
MODEL_FILE="yolo26n.pt"

# Parse arguments
SOURCE_FILE="${1:-test.mp4}"

cd "$SCRIPT_DIR"

# Download model if not exists
if [ ! -f "$MODEL_FILE" ]; then
    echo "Downloading YOLO26n model (5.3MB)..."
    wget -q --show-progress "$MODEL_URL" -O "$MODEL_FILE"
fi

# Build image if not exists
if ! sudo docker images "$IMAGE_NAME" --format "{{.Repository}}" 2>/dev/null | grep -q "$IMAGE_NAME"; then
    echo "Building YOLO26 Docker image..."
    sudo docker build --network host -t "$IMAGE_NAME" .
fi

echo "Running YOLO26 detection on: $SOURCE_FILE"
mkdir -p "$SCRIPT_DIR/output"

# Check if source file exists
if [ ! -f "$SOURCE_FILE" ]; then
    echo "ERROR: Source file not found: $SOURCE_FILE"
    echo "Usage: reComputer run yolo26 /path/to/video.mp4"
    exit 1
fi

# Get absolute path for mounting
SOURCE_ABS="$(realpath "$SOURCE_FILE")"

sudo docker run --rm \
    --runtime=nvidia \
    --network=host \
    -v /usr/local/cuda:/usr/local/cuda:ro \
    -v "$SCRIPT_DIR/output:/output" \
    -v "$SOURCE_ABS:/input/video.mp4:ro" \
    -e NVIDIA_VISIBLE_DEVICES=all \
    -e NVIDIA_DRIVER_CAPABILITIES=compute,utility \
    -e LD_LIBRARY_PATH=/usr/local/cuda/targets/sbsa-linux/lib:/usr/lib/aarch64-linux-gnu/nvidia \
    "$IMAGE_NAME" \
    --source /input/video.mp4

echo "Done! Check $SCRIPT_DIR/output/result.mp4"
