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
    pip install -r requirements.txt && \
    pip install -r backend/requirements-backend.txt


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

VOLUME [ "/Whisper-WebUI/models" ]
VOLUME [ "/Whisper-WebUI/outputs" ]
VOLUME [ "/Whisper-WebUI/backend" ]

ENV PATH="/Whisper-WebUI/venv/bin:$PATH"

ENTRYPOINT ["uvicorn", "backend.main:app", "--host", "0.0.0.0", "--port", "8000"]
