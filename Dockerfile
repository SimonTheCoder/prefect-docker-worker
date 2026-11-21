# --- Builder stage: use uv for fast dependency resolution ---
FROM ghcr.io/astral-sh/uv:python3.12-bookworm-slim AS builder

ARG PREFECT_VERSION
WORKDIR /app

# Create a virtual environment and install prefect[docker]
RUN uv venv /opt/venv \
    && uv pip install --python /opt/venv/bin/python "prefect[docker]==${PREFECT_VERSION}"

# --- Final stage: python 3.12 slim ---
FROM python:3.12-slim

ARG PREFECT_VERSION
LABEL prefect.version="${PREFECT_VERSION}"

WORKDIR /app

# Copy the virtual environment from builder
COPY --from=builder /opt/venv /opt/venv

ENV PATH="/opt/venv/bin:$PATH" \
    VIRTUAL_ENV="/opt/venv"

# Prefect default env vars (override at runtime)
ENV PREFECT_API_URL="" \
    PREFECT_WORKER_NAME="docker-worker" \
    PREFECT_WORK_POOL_NAME="default"

CMD ["prefect", "worker", "start", "--type", "docker"]
