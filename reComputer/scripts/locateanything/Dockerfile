# syntax=docker/dockerfile:1
FROM arm64v8/ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV PIP_DEFAULT_TIMEOUT=300
ENV PIP_RETRIES=10
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility

# System deps for OpenCV (headless), git, and glibc
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip libgomp1 libgl1 libglib2.0-0 git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Layer 1: torch alone (biggest download ~426MB + ~3GB CUDA deps).
# Isolated so a network failure here doesn't lose the other layers.
# --mount=type=cache caches downloaded wheels across build retries.
RUN --mount=type=cache,target=/root/.cache/pip \
    pip3 install --break-system-packages \
    -i https://mirrors.aliyun.com/pypi/simple/ --trusted-host mirrors.aliyun.com \
    torch==2.12.1

# Layer 2: torchvision + triton
RUN --mount=type=cache,target=/root/.cache/pip \
    pip3 install --break-system-packages \
    -i https://mirrors.aliyun.com/pypi/simple/ --trusted-host mirrors.aliyun.com \
    torchvision==0.27.1 triton==3.7.1

# Layer 3: web framework + inference deps + model deps (peft, lmdb, safetensors)
RUN --mount=type=cache,target=/root/.cache/pip \
    pip3 install --break-system-packages \
    -i https://mirrors.aliyun.com/pypi/simple/ --trusted-host mirrors.aliyun.com \
    "transformers>=4.57,<5" \
    "accelerate>=1.0" \
    "einops>=0.8" \
    "numpy>=1.26" \
    "Pillow>=10.0" \
    "opencv-python-headless>=4.11" \
    "fastapi>=0.100" \
    "uvicorn[standard]" \
    websockets \
    python-multipart \
    "huggingface_hub>=0.30" \
    "peft>=0.19" \
    "lmdb>=2.2" \
    "safetensors>=0.8"

# Dummy decord module: processing_locateanything.py imports decord at top level,
# but it's only used for training-time LMDB video reading — never at inference.
# decord has no prebuilt wheel for py3.12/aarch64, so a dummy satisfies the import.
RUN SITE_DIR=$(python3 -c "import site; print(site.getsitepackages()[0])") && \
    mkdir -p $SITE_DIR/decord && \
    printf 'class VideoReader:\n    def __init__(self,*a,**k): raise NotImplementedError\nclass VideoLoader:\n    def __init__(self,*a,**k): raise NotImplementedError\ndef cpu(*a,**k): raise NotImplementedError\ndef gpu(*a,**k): raise NotImplementedError\n' > $SITE_DIR/decord/__init__.py

# Engine: COPY the locateanything-batch source from build context.
# This version has the on_box callback needed by the web UI for progressive
# box streaming. (The stock GitHub repo may lack on_box — always use this.)
WORKDIR /app
COPY pyproject.toml /app/
COPY engine_README.md /app/README.md
COPY src/locateanything_batch /app/src/locateanything_batch
RUN pip3 install --break-system-packages -e .

# Web UI script (loads model at startup via main(), sets ws_max_size)
RUN mkdir -p /app/examples
COPY locate_web_ui.py /app/examples/locate_web_ui.py

EXPOSE 7860

ENV LA3B_MODEL=nvidia/LocateAnything-3B
ENV LA3B_VIDEO_DIM=512
ENV LA3B_VIDEO_TOK=16
ENV LA3B_DETECT_SKIP=5

# Run via the script directly so load() is called at startup (main thread),
# avoiding CUDA threading deadlocks when loading inside asyncio.to_thread.
ENTRYPOINT ["python3", "examples/locate_web_ui.py"]
