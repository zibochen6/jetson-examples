FROM arm64v8/ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip python3-venv libgomp1 \
    libx11-6 libxcb1 libxext6 libxrender1 \
    libgl1 libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install --no-cache-dir --break-system-packages \
    -i https://pypi.tuna.tsinghua.edu.cn/simple/ \
    --trusted-host pypi.tuna.tsinghua.edu.cn \
    ultralytics==8.4.83 \
    opencv-python-headless==4.13.0.92 \
    numpy

WORKDIR /app
COPY detect.py .
COPY yolo26n.pt .

ENTRYPOINT ["python3", "detect.py"]
CMD ["--source", "test.mp4"]
