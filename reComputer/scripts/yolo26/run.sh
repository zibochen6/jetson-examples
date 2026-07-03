#!/bin/bash
set -e

IMAGE_VERSION="8.4.54"
SLIM_IMAGE="ultralytics/ultralytics:${IMAGE_VERSION}-jetson-slim"
SCRIPT_DIR="$(cd "$(dirname "$(realpath "$0")")" && pwd)"

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --slim       Use the slimmed-down image (~3-4 GB) instead of the fat image (~15 GB).
               Builds the slim image if not already present.
    --shell      Drop into an interactive shell inside the container (with --slim).
  --webcam     Run real-time USB webcam detection (with --slim).
  -h, --help   Show this help message.

Examples:
  $0                  # Run with fat image (15.3 GB)
  $0 --slim           # Run with slim image (~2.5 GB) - requires JetPack 6.x
  $0 --slim --shell   # Run slim image and open shell
  $0 --slim --webcam  # Run slim image with USB webcam object detection
EOF
}

# Parse arguments
USE_SLIM=false
INTERACTIVE_SHELL=false
WEBCAM_MODE=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --slim)
            USE_SLIM=true
            shift
            ;;
        --shell)
            INTERACTIVE_SHELL=true
            shift
            ;;
        --webcam)
            WEBCAM_MODE=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

get_l4t_version() {
    local l4t_version=""
    if [ -f /etc/nv_tegra_release ]; then
        local release_line
        release_line=$(head -n 1 /etc/nv_tegra_release)
        if [[ $release_line =~ R([0-9]+)\ *\(release\),\ REVISION:\ ([0-9]+\.[0-9]+) ]]; then
            local major="${BASH_REMATCH[1]}"
            local revision="${BASH_REMATCH[2]}"
            l4t_version="${major}.${revision}"
        fi
    fi
    echo "$l4t_version"
}

L4T_VERSION=$(get_l4t_version)
echo "Detected L4T version: $L4T_VERSION"

# === Slim mode ===
if $USE_SLIM; then
    if [[ "$L4T_VERSION" != "36."* ]]; then
        echo "Error: Slim image is only supported on JetPack 6.x (L4T 36.x)."
        echo "Detected: L4T $L4T_VERSION"
        exit 1
    fi

    echo "=== Slim mode (JetPack 6.x only) ==="

    # Check if slim image exists locally
    if sudo docker images "$SLIM_IMAGE" --format '{{.Size}}' 2>/dev/null | grep -q .; then
        echo "Slim image found: $SLIM_IMAGE ($(sudo docker images "$SLIM_IMAGE" --format '{{.Size}}'))"
    else
        echo "Slim image not found. Building..."
        echo "This may take 15-30 minutes on first run."
        sudo docker build \
            -f "$SCRIPT_DIR/Dockerfile.slim" \
            -t "$SLIM_IMAGE" \
            "$SCRIPT_DIR"
    fi

    echo "Starting slim container..."
    echo "Host GPU libs: /usr/local/cuda (CUDA), /usr/lib/aarch64-linux-gnu/nvidia (NVIDIA), /usr/lib/aarch64-linux-gnu (stubs)"
    echo "Host TRT bindings: /usr/lib/python3/dist-packages/tensorrt"

    COMMON_RUN_OPTS=(
        --rm
        -it
        --ipc=host
        --runtime=nvidia
        --network=host
        --name=yolo26_slim
        -e CUDA_MODULE_LOADING=LAZY
        -e NVIDIA_VISIBLE_DEVICES=all
        -e NVIDIA_DRIVER_CAPABILITIES=all
        -e LD_LIBRARY_PATH=/usr/local/lib/python3.10/dist-packages/onnxruntime/capi:/host-nvidia:/host-syslibs:/host-cuda
        -v /usr/local/cuda/lib64:/host-cuda:ro
        -v /usr/lib/aarch64-linux-gnu/nvidia:/host-nvidia:ro
        -v /usr/lib/aarch64-linux-gnu:/host-syslibs:ro
        -v /usr/lib/python3/dist-packages/tensorrt:/host-tensorrt:ro
    )

    if $INTERACTIVE_SHELL; then
        sudo docker run "${COMMON_RUN_OPTS[@]}" "$SLIM_IMAGE"
    elif $WEBCAM_MODE; then
        "$SCRIPT_DIR/webcam.sh" --slim
    else
        sudo docker run "${COMMON_RUN_OPTS[@]}" "$SLIM_IMAGE" python3 -c "from ultralytics import YOLO; print('YOLO26 slim ready')"
    fi
    exit 0
fi

# === Fat image mode (default) ===
case "$L4T_VERSION" in
    35.*)
        IMAGE_NAME="ultralytics/ultralytics:${IMAGE_VERSION}-jetson-jetpack5"
        ;;
    36.*)
        IMAGE_NAME="ultralytics/ultralytics:${IMAGE_VERSION}-jetson-jetpack6"
        ;;
    38.*)
        IMAGE_NAME="ultralytics/ultralytics:${IMAGE_VERSION}-nvidia-arm64"
        ;;
    *)
        echo "Error: L4T version $L4T_VERSION is not supported by this YOLO26 demo."
        echo "Supported JetPack versions: 5.x, 6.x, and 7.x."
        exit 1
        ;;
esac

echo "Using Docker image: $IMAGE_NAME"
if $WEBCAM_MODE; then
    "$SCRIPT_DIR/webcam.sh"
else
    sudo docker pull "$IMAGE_NAME"
    sudo docker run -it --ipc=host --runtime=nvidia "$IMAGE_NAME"
fi
