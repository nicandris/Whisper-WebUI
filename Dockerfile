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
# We redirect stderr (2) to /dev/null to silence "No such file or directory" warnings
# which occur when one find/delete command removes files targeted by a subsequent command.
RUN ( \
    find venv \( -name '*.pyc' -o -name '*.pyo' \) -delete && \
    find venv -name '__pycache__' -type d -exec rm -r {} + && \
    find venv -wholename 'venv/lib/python*/site-packages/*.dist-info' -type d -prune -exec rm -rf {} + && \
    \
    # Aggressive Cleanup: Remove unnecessary files that bloat library sizes (tests, docs, headers)
    find venv -type f -name '*.a' -delete && \
    find venv -type f -name 'test*' -delete && \
    find venv -type d -name 'test*' -exec rm -rf {} + && \
    find venv -type d -name 'doc' -exec rm -rf {} + \
) 2>/dev/null
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
