# syntax=docker/dockerfile:1.4
FROM debian:bookworm-slim AS builder

# Install dependencies with cache mount for faster rebuilds
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends curl git python3 python3-pip python3-venv && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /Whisper-WebUI

WORKDIR /Whisper-WebUI

# Copy requirements first for better layer caching
COPY requirements.txt .
COPY backend/requirements-backend.txt backend/

# Install dependencies with pip cache mount
RUN --mount=type=cache,target=/root/.cache/pip \
    python3 -m venv venv && \
    . venv/bin/activate && \
    pip install --upgrade pip setuptools wheel && \
    pip install --no-cache-dir -r requirements.txt && \
    pip install --no-cache-dir -r backend/requirements-backend.txt && \
    # Aggressively clean up venv to reduce image size \
    find venv -type d -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true && \
    find venv -type f \( -name '*.pyc' -o -name '*.pyo' \) -delete 2>/dev/null || true && \
    find venv -type d -name 'test*' -exec rm -rf {} + 2>/dev/null || true && \
    find venv -type d -name 'tests' -exec rm -rf {} + 2>/dev/null || true && \
    find venv -type f -name 'test_*.py' -delete 2>/dev/null || true && \
    find venv -type d -name 'doc*' -exec rm -rf {} + 2>/dev/null || true && \
    find venv -type f -name '*.md' -delete 2>/dev/null || true && \
    find venv -type d -name '*.dist-info' -exec rm -rf {} + 2>/dev/null || true && \
    find venv -type d -name '*.egg-info' -exec rm -rf {} + 2>/dev/null || true && \
    find venv -type f -name '*.a' -delete 2>/dev/null || true && \
    find venv -type f -name '*.o' -delete 2>/dev/null || true && \
    find venv -type d -name 'include' -exec rm -rf {} + 2>/dev/null || true && \
    # Remove pip, setuptools, wheel (not needed at runtime) \
    rm -rf venv/lib/python*/site-packages/pip* 2>/dev/null || true && \
    rm -rf venv/lib/python*/site-packages/setuptools* 2>/dev/null || true && \
    rm -rf venv/lib/python*/site-packages/wheel* 2>/dev/null || true


FROM python:3.11-slim AS runtime

# Install only runtime dependencies (no git, no build tools, no curl)
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends ffmpeg && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /Whisper-WebUI

# Copy venv first (changes less frequently than source code)
COPY --from=builder /Whisper-WebUI/venv /Whisper-WebUI/venv

# Copy application source code last (changes most frequently)
COPY . .

VOLUME [ "/Whisper-WebUI/models" ]
VOLUME [ "/Whisper-WebUI/outputs" ]
VOLUME [ "/Whisper-WebUI/backend" ]

ENV PATH="/Whisper-WebUI/venv/bin:$PATH"

ENTRYPOINT ["uvicorn", "backend.main:app", "--host", "0.0.0.0", "--port", "8000"]
