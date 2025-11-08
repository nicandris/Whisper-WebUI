# syntax=docker/dockerfile:1.4
FROM debian:bookworm-slim AS builder

# 1. Install dependencies with cache mount for faster rebuilds
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends curl git python3 python3-pip python3-venv && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /Whisper-WebUI

WORKDIR /Whisper-WebUI

# 2. Copy requirements first for better layer caching
COPY requirements.txt .

# 3. Install dependencies into venv with pip cache mount
RUN --mount=type=cache,target=/root/.cache/pip \
    python3 -m venv venv && \
    . venv/bin/activate && \
    pip install --upgrade pip setuptools wheel && \
    pip install -r requirements.txt

# 4. Clean up venv (suppress all error messages)
RUN ( \
    . venv/bin/activate 2>/dev/null || true; \
    find venv -type d -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true; \
    find venv -type f -name '*.pyc' -delete 2>/dev/null || true; \
    find venv -type f -name '*.pyo' -delete 2>/dev/null || true; \
    ) 2>/dev/null || true


FROM debian:bookworm-slim AS runtime

# Install runtime dependencies with cache mount
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends curl ffmpeg python3 && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /Whisper-WebUI

# Copy venv first (changes less frequently than source code)
COPY --from=builder /Whisper-WebUI/venv /Whisper-WebUI/venv

# Copy application source code last (changes most frequently)
COPY . .

# Volumes for persistent storage outside the container layers
VOLUME [ "/Whisper-WebUI/models" ]
VOLUME [ "/Whisper-WebUI/outputs" ]

# Set environment variables for the runtime
ENV PATH="/Whisper-WebUI/venv/bin:$PATH"

ENTRYPOINT [ "python", "app.py" ]
