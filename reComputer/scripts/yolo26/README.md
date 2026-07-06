# Quickly Run YOLO26 on Jetson

This example runs YOLO26 object detection on Jetson devices with NVIDIA GPU acceleration using a lightweight custom Docker image.

## Supported Devices

| JetPack | Device |
| ------- | ------ |
| 5.x | Jetson Xavier NX/AGX |
| 6.x | Jetson Orin Nano/NX |
| 7.x | reComputer J4012, Thor J6015 |

## Quick Start

### One-Command Run

Install `jetson-examples`:

```sh
pip3 install jetson-examples
```

Restart your reComputer:

```sh
sudo reboot
```

Run YOLO26 detection:

```sh
reComputer run yolo26
```

This will automatically:
1. Build a lightweight Docker image (~500MB) with YOLO26 dependencies
2. Mount host CUDA libraries (no duplication)
3. Run inference on the bundled test video
4. Save results to `output/result.mp4`

## Custom Video

Run detection on your own video:

```sh
reComputer run yolo26 /path/to/your/video.mp4
```

Example:

```sh
# Run on a specific video file
reComputer run yolo26 ~/Videos/traffic.mp4

# Run on a video in the current directory
reComputer run yolo26 ./my_video.mp4
```

Results are saved to `scripts/yolo26/output/result.mp4`.

## Model Export

### Export to ONNX

```sh
# Inside the container or with ultralytics installed
yolo export model=yolo26n.pt format=onnx imgsz=640
```

### Export to TensorRT

```sh
# For better performance on Jetson
yolo export model=yolo26n.pt format=engine imgsz=640 half=True
```

### Export to NCNN (Lightweight)

```sh
# For edge deployment
yolo export model=yolo26n.pt format=ncnn imgsz=640
```

## Running Without reComputer CLI

### Build the Docker Image

```sh
cd /path/to/reComputer/scripts/yolo26
docker build -t yolo26:latest .
```

### Run with Custom Video

```sh
docker run --rm \
    --runtime=nvidia \
    --network=host \
    -v /usr/local/cuda:/usr/local/cuda:ro \
    -v $(pwd)/output:/output \
    -v /path/to/video.mp4:/input/video.mp4:ro \
    -e NVIDIA_VISIBLE_DEVICES=all \
    -e NVIDIA_DRIVER_CAPABILITIES=compute,utility \
    -e LD_LIBRARY_PATH=/usr/local/cuda/targets/sbsa-linux/lib:/usr/lib/aarch64-linux-gnu/nvidia \
    yolo26:latest \
    --source /input/video.mp4
```

### Run with Camera

```sh
# Camera index 0 (default USB camera)
docker run --rm -it \
    --runtime=nvidia \
    --network=host \
    --device=/dev/video0:/dev/video0 \
    -v /usr/local/cuda:/usr/local/cuda:ro \
    -e NVIDIA_VISIBLE_DEVICES=all \
    -e NVIDIA_DRIVER_CAPABILITIES=compute,utility \
    -e LD_LIBRARY_PATH=/usr/local/cuda/targets/sbsa-linux/lib:/usr/lib/aarch64-linux-gnu/nvidia \
    yolo26:latest \
    --source 0
```

## Python Script Options

The `detect.py` script supports these arguments:

| Argument | Default | Description |
|----------|---------|-------------|
| `--source` | `0` | Camera index (`0`) or video file path |
| `--model` | `yolo26n.pt` | Model file path (`.pt`, `.onnx`, `.engine`) |
| `--conf` | `0.5` | Confidence threshold (0.0 - 1.0) |
| `--save` | auto | Output path (auto: `/output/result.mp4` if headless) |
| `--imgsz` | `640` | Inference size (pixels) |

### Examples

```sh
# Use custom model with high confidence
docker run --rm \
    --runtime=nvidia \
    --network=host \
    -v /usr/local/cuda:/usr/local/cuda:ro \
    -v $(pwd)/output:/output \
    -v /path/to/custom_model.pt:/app/custom_model.pt:ro \
    -v /path/to/video.mp4:/input/video.mp4:ro \
    -e NVIDIA_VISIBLE_DEVICES=all \
    -e NVIDIA_DRIVER_CAPABILITIES=compute,utility \
    -e LD_LIBRARY_PATH=/usr/local/cuda/targets/sbsa-linux/lib:/usr/lib/aarch64-linux-gnu/nvidia \
    yolo26:latest \
    --source /input/video.mp4 \
    --model /app/custom_model.pt \
    --conf 0.7 \
    --imgsz 1280
```

## Using Pre-built Ultralytics Images

If you prefer the official Ultralytics images:

```sh
# JetPack 7.x
t=ultralytics/ultralytics:8.4.54-nvidia-arm64
sudo docker pull $t
sudo docker run -it --ipc=host --runtime=nvidia $t

# JetPack 6.x
t=ultralytics/ultralytics:8.4.54-jetson-jetpack6
sudo docker pull $t
sudo docker run -it --ipc=host --runtime=nvidia $t

# JetPack 5.x
t=ultralytics/ultralytics:8.4.54-jetson-jetpack5
sudo docker pull $t
sudo docker run -it --ipc=host --runtime=nvidia $t
```

## Performance

Typical performance on Jetson devices:

| Device | Model | FPS | Resolution |
|--------|-------|-----|------------|
| Thor J6015 | YOLO26n | 75 | 640x480 |
| Orin Nano | YOLO26n | 45 | 640x480 |

## Troubleshooting

### CUDA Not Found

Ensure NVIDIA runtime is installed and configured:

```sh
# Check nvidia-smi
nvidia-smi

# Check Docker runtime
docker info | grep -i runtime
```

### Video Cannot Open

- Verify the video file exists and is accessible
- Check file permissions
- Ensure video codec is supported (MP4 with H.264 recommended)

### Low FPS

- Reduce input resolution: `--imgsz 320`
- Use a smaller model (nano vs small)
- Check GPU temperature: `tegrastats`

## File Structure

```
yolo26/
├── Dockerfile          # Lightweight Docker image definition
├── detect.py           # Python detection script
├── run.sh              # Shell wrapper for docker run
├── config.yaml         # JetPack version and resource requirements
├── init.sh             # Environment initialization
├── test.mp4            # Sample video for testing
├── yolo26n.pt          # YOLO26 nano model
└── output/             # Detection results saved here
```

## Reference

- https://github.com/ultralytics/ultralytics
- https://docs.ultralytics.com/detect/
