FROM debian:bookworm-slim AS builder

# 1. Install dependencies
RUN apt-get update && \
    apt-get install -y curl git python3 python3-pip python3-venv && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* && \
    mkdir -p /Whisper-WebUI

WORKDIR /Whisper-WebUI

COPY requirements.txt .

# 2. Install dependencies into venv
RUN python3 -m venv venv && \
    . venv/bin/activate && \
    pip install -U -r requirements.txt

# --- OPTIMIZATION: Clean up the venv before copying it ---
RUN find venv \( -name '*.pyc' -o -name '*.pyo' \) -delete && \
    find venv -name '__pycache__' -type d -exec rm -r {} + && \
    find venv -wholename 'venv/lib/python*/site-packages/*.dist-info' -type d -prune -exec rm -rf {} +
# --------------------------------------------------------


FROM debian:bookworm-slim AS runtime

# 3. Install runtime dependencies (FFmpeg is crucial for Whisper)
RUN apt-get update && \
    apt-get install -y curl ffmpeg python3 && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

WORKDIR /Whisper-WebUI

# 4. Copy application source code
COPY . .
# 5. Copy cleaned virtual environment
COPY --from=builder /Whisper-WebUI/venv /Whisper-WebUI/venv

# Volumes for persistent storage outside the container layers
VOLUME [ "/Whisper-WebUI/models" ]
VOLUME [ "/Whisper-WebUI/outputs" ]

# Set environment variables for the runtime
ENV PATH="/Whisper-WebUI/venv/bin:$PATH"
# Note: Ensure the Python version is correct here if not 3.11
ENV LD_LIBRARY_PATH=/Whisper-WebUI/venv/lib64/python3.11/site-packages/nvidia/cublas/lib:/Whisper-WebUI/venv/lib64/python3.11/site-packages/nvidia/cudnn/lib

ENTRYPOINT [ "python", "app.py" ]
