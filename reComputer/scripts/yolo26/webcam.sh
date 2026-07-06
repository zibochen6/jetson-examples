#!/bin/bash
# ============================================================================
# webcam.sh - Run YOLO26 real-time USB webcam detection on Jetson
#
# Supports both fat image (JetPack 5/6/7) and slim image (JetPack 6 only).
# Uses ffmpeg V4L2 pipe for frame capture, container YOLO for inference.
# ============================================================================

IMAGE_VERSION="8.4.54"
SLIM_IMAGE="ultralytics/ultralytics:${IMAGE_VERSION}-jetson-slim"

# Resolve script directory (handles symlinks, spaces, etc.)
SCRIPT_DIR="$(cd "$(dirname "$(realpath "$0")")" && pwd)"

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Start YOLO26 real-time USB webcam object detection.

Options:
  --slim         Use the slim image (~2.6 GB) instead of fat (~15 GB).
                 JetPack 6.x required.
  --display      Force X11 window output (default: auto-detect).
  --model MODEL  Model to use (default: yolo26n.pt).
                   Pre-installed: yolo26n.pt, yolov8n.pt, yolov8s.pt
  --device DEV   Video device path (default: auto-detect via host OpenCV).
  --imgsz N      Inference image size (default: 640).
  --conf N       Confidence threshold 0.0-1.0 (default: 0.25).
  --fps          Show FPS overlay (default: on).
  -h, --help     Show this help.

Examples:
  $0                           # Auto-detect webcam, fat image
  $0 --slim                    # Slim image, auto-detect webcam
  $0 --slim --device /dev/video1  # Specify device
  $0 --model yolov8s.pt       # Use heavier model
EOF
}

USE_SLIM=false
FORCE_DISPLAY=false
MODEL="yolo26n.pt"
VIDEO_DEVICE=""
IMGSZ=640
CONF=0.25
SHOW_FPS=true

while [[ $# -gt 0 ]]; do
    case "$1" in
        --slim)      USE_SLIM=true; FORCE_DISPLAY=true; shift ;;
        --display)   FORCE_DISPLAY=true; shift ;;
        --model)     MODEL="$2"; shift 2 ;;
        --device)    VIDEO_DEVICE="$2"; shift 2 ;;
        --imgsz)     IMGSZ="$2"; shift 2 ;;
        --conf)      CONF="$2"; shift 2 ;;
        --fps|--no-fps) SHOW_FPS="$([ "$1" = "--fps" ] && echo true || echo false)"; shift ;;
        -h|--help)   usage; exit 0 ;;
        *)           echo "Unknown: $1"; usage; exit 1 ;;
    esac
done

# --- Detect L4T / JetPack ---
get_l4t_version() {
    local ver=""
    if [ -f /etc/nv_tegra_release ]; then
        local line
        line=$(head -n 1 /etc/nv_tegra_release)
        if [[ $line =~ R([0-9]+)\ *\(release\),\ REVISION:\ ([0-9]+\.[0-9]+) ]]; then
            ver="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}"
        fi
    fi
    echo "$ver"
}

L4T_VERSION=$(get_l4t_version)
echo "L4T: $L4T_VERSION"

# --- Detect video device ---
# Strategy: check for real character device nodes (c major:minor), not empty dirs
find_video_device() {
    # Log each video device found and its type
    echo "DEBUG: find_video_device() checking /dev/video*" >&2
    for dev in /dev/video*; do
        echo "DEBUG:   checking $dev" >&2
        echo "DEBUG:     -c test: $( [ -c "$dev" ] && echo YES || echo NO )" >&2
        if [ -c "$dev" ]; then
            echo "DEBUG:     $dev is a character device, checking V4L2 major number" >&2
            local major minor
            major=$(stat -c %T "$dev" 2>/dev/null)
            minor=$(stat -c %t "$dev" 2>/dev/null)
            echo "DEBUG:     major=0x$major minor=0x$minor" >&2
            # Video4Linux devices are major 81
            if [[ -n "$major" ]] && [[ "$major" =~ ^[0-9a-f]+$ ]]; then
                local maj_int=$((16#$major))
                echo "DEBUG:     major int=$maj_int (expect 81)" >&2
                if [ "$maj_int" -eq 81 ] 2>/dev/null; then
                    echo "DEBUG:     MATCH! returning $dev" >&2
                    echo "$dev"
                    return 0
                fi
            fi
        else
            echo "DEBUG:     $dev is NOT a char device (probably empty dir)" >&2
        fi
    done
    echo "DEBUG: find_video_device() found nothing" >&2
    return 1
}

if [ -z "$VIDEO_DEVICE" ]; then
    echo -n "Detecting video device... " >&2
    DETECTED=$(find_video_device) || true
    if [ -n "$DETECTED" ] && [ -c "$DETECTED" ]; then
        VIDEO_DEVICE="$DETECTED"
        echo "found: $VIDEO_DEVICE" >&2
    else
        echo "not found" >&2
    fi
fi

if [ -z "$VIDEO_DEVICE" ] || [ ! -c "$VIDEO_DEVICE" ]; then
    echo "ERROR: No usable video device found."
    echo "       Check: ls -la /dev/video*"
    echo "       Use --device /dev/videoN to specify manually."
    exit 1
fi
echo "Video device: $VIDEO_DEVICE"

# --- Detect display ---
DISPLAY="${DISPLAY:-:0}"
if $FORCE_DISPLAY || ( [ -n "$DISPLAY" ] && xdpyinfo -display "$DISPLAY" >/dev/null 2>&1 ); then
    echo "Display: $DISPLAY (X11 window)"
else
    DISPLAY=""
    echo "Display: none (headless mode)"
fi

# Grant X11 access
xhost +local:docker 2>/dev/null || true

# --- Build docker run options ---
VIDEO_MOUNTS="-v $VIDEO_DEVICE:$VIDEO_DEVICE:rw"

DOCKER_OPTS=(
    --rm
    --ipc=host
    --runtime=nvidia
    --network=host
    -e CUDA_MODULE_LOADING=LAZY
    -e NVIDIA_VISIBLE_DEVICES=all
    -e NVIDIA_DRIVER_CAPABILITIES=all
    -e DISPLAY="$DISPLAY"
    -v /tmp/.X11-unix:/tmp/.X11-unix:rw
    -v /usr/lib/aarch64-linux-gnu/nvidia:/host-nvidia:ro
    -v /usr/lib/aarch64-linux-gnu:/host-syslibs:ro
    -v /usr/local/cuda/lib64:/host-cuda:ro
    $VIDEO_MOUNTS
)

if $USE_SLIM; then
    if [[ "$L4T_VERSION" != "36."* ]]; then
        echo "Error: Slim image only supports JetPack 6.x (L4T 36.x)"
        exit 1
    fi
    DOCKER_OPTS+=(
        -e LD_LIBRARY_PATH=/usr/local/lib/python3.10/dist-packages/onnxruntime/capi:/host-nvidia:/host-syslibs:/host-cuda
        -v /usr/lib/python3/dist-packages/tensorrt:/host-tensorrt:ro
    )
    IMG="$SLIM_IMAGE"
else
    case "$L4T_VERSION" in
        35.*) IMG="ultralytics/ultralytics:${IMAGE_VERSION}-jetson-jetpack5" ;;
        36.*) IMG="ultralytics/ultralytics:${IMAGE_VERSION}-jetson-jetpack6" ;;
        38.*) IMG="ultralytics/ultralytics:${IMAGE_VERSION}-nvidia-arm64" ;;
        *)    echo "Error: L4T $L4T_VERSION not supported"; exit 1 ;;
    esac
fi

echo "Image: $IMG"
echo "Model: $MODEL"

# --- Write python script ---
FPS_FLAG=$( [ "$SHOW_FPS" = true ] && echo "True" || echo "False" )

PY_SCRIPT="/tmp/yolo26_webcam_$$.py"
cat > "$PY_SCRIPT" << 'PYSCRIPT'
#!/usr/bin/env python3
import cv2
import subprocess
import sys
import time
import numpy as np

from ultralytics import YOLO

# Config (injected by bash)
DEVICE = 'VIDEODEV'
IMGSZ = IMGSZVAL
CONF = CONFVAL
FPS_SHOW = FPSFLAG

model = YOLO('/root/.cache/Ultralytics/yolo26n.pt')

# Start ffmpeg V4L2 -> raw BGR frames
print('Starting ffmpeg V4L2 capture from', DEVICE)
proc = subprocess.Popen(
    ['ffmpeg', '-f', 'v4l2',
     '-input_format', 'yuyv422',
     '-video_size', '640x480',
     '-framerate', '30',
     '-i', DEVICE,
     '-f', 'rawvideo', '-pix_fmt', 'bgr24', '-'],
    stdout=subprocess.PIPE,
    stderr=subprocess.DEVNULL,
    bufsize=640*480*3*2
)

print('Starting YOLO26 detection. Press q or Ctrl+C to quit.')

fps_count = 0
t_start = time.time()
t_last = time.time()

while True:
    raw = proc.stdout.read(640 * 480 * 3)
    if len(raw) < 640 * 480 * 3:
        print('Frame stream ended (got %d bytes)' % len(raw))
        break

    frame = np.frombuffer(raw, dtype=np.uint8).reshape(480, 640, 3).copy()

    results = model(frame, imgsz=IMGSZ, conf=CONF, verbose=False, show=FPS_SHOW)
    annotated = results[0].plot()

    cv2.imshow('YOLO26 USB Webcam', annotated)

    fps_count += 1
    if fps_count % 30 == 0:
        elapsed = time.time() - t_last
        print('FPS: %.1f' % (30.0 / elapsed), flush=True)
        t_last = time.time()

    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

proc.terminate()
proc.wait()
cv2.destroyAllWindows()
total = time.time() - t_start
avg_fps = fps_count / total if total > 0 else 0
print('Exited. Frames: %d, Avg FPS: %.1f' % (fps_count, avg_fps))
PYSCRIPT

# Inject config values
sed -i "s|VIDEODEV|$VIDEO_DEVICE|g" "$PY_SCRIPT"
sed -i "s|IMGSZVAL|$IMGSZ|g"     "$PY_SCRIPT"
sed -i "s|CONFVAL|$CONF|g"       "$PY_SCRIPT"
sed -i "s|FPSFLAG|$FPS_FLAG|g"   "$PY_SCRIPT"

# Copy into container and run
docker cp "$PY_SCRIPT" "$IMG:/tmp/yolo26_webcam.py" 2>/dev/null
rm -f "$PY_SCRIPT"

docker run "${DOCKER_OPTS[@]}" "$IMG" \
    python3 /tmp/yolo26_webcam.py
