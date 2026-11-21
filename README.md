# Prefect Docker Worker

A minimal Docker image for running [Prefect](https://www.prefect.io/) Docker Workers, built with [uv](https://github.com/astral-sh/uv) for fast dependency resolution.

## ⚠️ Security Warning: Docker Socket Access

> **This worker requires mounting the host's Docker socket (`/var/run/docker.sock`) into the container.**
>
> **This grants the container FULL ROOT-LEVEL CONTROL over the host's Docker daemon and, by extension, the host system itself.**
>
> Specifically, a compromised or malicious workload running inside a managed container can:
>
> - **Escape the container** — mount the host filesystem (e.g., `docker run -v /:/host`), giving full root access to the host.
> - **Steal secrets** — read environment variables, mounted volumes, and credentials from other containers on the same host.
> - **Launch arbitrary containers** — spin up new containers with any image, volume, or network access.
> - **Exhaust resources** — fork bombs, disk fill, or network saturation affecting all workloads on the host.
> - **Persist across restarts** — modify the Docker daemon configuration or install backdoors.
>
> ### Mitigations
>
> | Measure | Description |
> |---------|-------------|
> | **Isolate the host** | Run the worker on a dedicated VM or a disposable machine, never on a multi-tenant or production-critical host. |
> | **Restrict the socket** | Use [Docker Socket Proxy](https://github.com/tecnativa/docker-socket-proxy) to expose only the API endpoints Prefect needs (e.g., `POST /containers/create`, `GET /containers/{id}/json`). |
> | **Use a rootless Docker daemon** | Run Docker in rootless mode so the socket grants user-level, not root-level, access. |
> | **Network segmentation** | Place the worker host on a segregated network with no access to sensitive internal resources. |
> | **Ephemeral workloads** | Treat any container spawned by the worker as untrusted. Use read-only filesystems, no privileged mode, and resource limits. |
> | **Monitor & audit** | Enable Docker daemon audit logging and monitor for unexpected container creation or volume mounts. |
>
> **If you cannot accept these risks, consider using a different worker type (e.g., Kubernetes, process) or running Prefect's built-in `docker` worker directly on the host without an additional container layer.**

## Image Tags

Images are pushed to GitHub Container Registry (`ghcr.io`) and tagged with:

| Tag | Meaning |
|-----|---------|
| `<prefect-version>` | e.g. `3.2.4` — matches the installed Prefect version (recommended) |
| `main` | Latest build from the `main` branch |
| `sha-<short-sha>` | Specific commit |

**Pin to a Prefect version tag that matches your server's version** to avoid compatibility issues.

## Building Locally

```bash
# Build with a specific Prefect version
docker build --build-arg PREFECT_VERSION=3.2.4 -t prefect-docker-worker:3.2.4 .

# Or let it resolve latest (for local testing)
docker build --build-arg PREFECT_VERSION=$(curl -s https://pypi.org/pypi/prefect/json | python3 -c "import sys,json; print(json.load(sys.stdin)['info']['version'])") -t prefect-docker-worker:latest .
```

## Running

### With Docker Compose

```bash
cp .env.example .env
# Edit .env — set PREFECT_API_URL at minimum
docker compose up -d
```

### With Docker CLI

```bash
docker run -d \
  --name prefect-docker-worker \
  -e PREFECT_API_URL=http://your-server:4200/api \
  -e PREFECT_WORKER_NAME=my-worker \
  -e PREFECT_WORK_POOL_NAME=default \
  -v /var/run/docker.sock:/var/run/docker.sock \
  ghcr.io/<owner>/prefect-docker-worker:<prefect-version>
```

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `PREFECT_API_URL` | *(required)* | URL of your Prefect server or Cloud workspace API |
| `PREFECT_WORKER_NAME` | `docker-worker` | Name of this worker instance |
| `PREFECT_WORK_POOL_NAME` | `default` | Work pool to register with |

## How It Works

```
┌─────────────────────────────────────────────────────┐
│  Builder (uv:python3.12-bookworm-slim)             │
│  • uv venv + uv pip install prefect[docker]==X.Y.Z │
└──────────────────────┬──────────────────────────────┘
                       │ COPY /opt/venv
                       ▼
┌─────────────────────────────────────────────────────┐
│  Final (python:3.12-slim)                          │
│  • Prefect worker starts in "docker" mode          │
│  • Talks to Docker daemon via mounted socket       │
│  • Spawns task containers on the host              │
└─────────────────────────────────────────────────────┘
```

## CI/CD

The GitHub Actions workflow (`.github/workflows/build-and-push.yml`) is **manually triggered** via:

**Actions → Build & Push to GHCR → Run workflow**

It resolves the latest Prefect version from PyPI, builds the image, and pushes it to `ghcr.io` tagged with that version.

## License

MIT
