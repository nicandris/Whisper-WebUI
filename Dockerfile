FROM debian:bookworm-slim AS builder

# 1. Install dependencies
RUN apt-get update && \
    apt-get install -y curl git python3 python3-pip python3-venv && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* && \
    mkdir -p /Whisper-WebUI

WORKDIR /Whisper-WebUI

COPY requirements.txt .

# 2. Install dependencies into venv
# Use --no-cache-dir to prevent pip cache from accumulating in this layer
RUN python3 -m venv venv && \
    . venv/bin/activate && \
    pip install --no-cache-dir -U -r requirements.txt

# --- AGGRESSIVE OPTIMIZATION: Clean up the venv before copying it ---
# We chain cleanup commands using '&&' and add '|| true' to ensure the
# entire RUN command does not fail if one of the find/delete operations
# hits a conflict or fails to find a file.
RUN find venv \( -name '*.pyc' -o -name '*.pyo' \) -delete || true && \
    find venv -name '__pycache__' -type d -exec rm -r {} + || true && \
    find venv -wholename 'venv/lib/python*/site-packages/*.dist-info' -type d -prune -exec rm -rf {} + || true && \
    \
    # Aggressive Cleanup: Remove unnecessary files that bloat library sizes (tests, docs, headers)
    find venv -type f -name '*.a' -delete || true && \
    find venv -type f -name 'test*' -delete || true && \
    find venv -type d -name 'test*' -exec rm -rf {} + || true && \
    find venv -type d -name 'doc' -exec rm -rf {} + || true
# --------------------------------------------------------


FROM debian:bookworm-slim AS runtime

# 3. Install runtime dependencies (FFmpeg is crucial for Whisper)
RUN apt-get update && \
    apt-get install -y curl ffmpeg python3 && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

WORKDIR /Whisper-WebUI

# 4. Copy application source code
COPY . .
# 5. Copy cleaned virtual environment (This is the critical line that needs less data)
COPY --from=builder /Whisper-WebUI/venv /Whisper-WebUI/venv

# Volumes for persistent storage outside the container layers
VOLUME [ "/Whisper-WebUI/models" ]
VOLUME [ "/Whisper-WebUI/outputs" ]

# Set environment variables for the runtime
ENV PATH="/Whisper-WebUI/venv/bin:$PATH"
# Note: Ensure the Python version is correct here if not 3.11
ENV LD_LIBRARY_PATH=/Whisper-WebUI/venv/lib64/python3.11/site-packages/nvidia/cublas/lib:/Whisper-WebUI/venv/lib64/python3.11/site-packages/nvidia/cudnn/lib

ENTRYPOINT [ "python", "app.py" ]
