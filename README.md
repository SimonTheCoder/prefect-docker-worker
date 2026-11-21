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

### SELinux hosts (RHEL / Fedora / CentOS / Rocky)

On SELinux-enabled hosts (`getenforce` returns `Enforcing`), mounting the socket
with `:z` is **not** enough — the container is still denied `connectto` on the
`unix_stream_socket` (AVC: `container_t` → `container_runtime_t`). You will see:

```
RuntimeError: Could not connect to Docker.
... PermissionError: [Errno 13] Permission denied
```

Fix it by disabling the SELinux label for this one container:

```yaml
services:
  prefect-docker-worker:
    security_opt:
      - label=disable
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
```

Or with the CLI: add `--security-opt label=disable`.

> `label=disable` removes SELinux confinement for this container. Since it
already has full control of the Docker daemon, this is not a meaningful
additional exposure — but it is the reason the isolated-host mitigations above
matter.

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

## Disclaimer

**USE AT YOUR OWN RISK.**

This project is provided "as is", without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose, and non-infringement.

- The author(s) and contributor(s) of this repository **accept no responsibility or liability** for any damages, data loss, security breaches, service disruption, or other harm — direct, indirect, incidental, or consequential — arising from the use, misuse, or inability to use this project or its container images.
- Running this worker with host Docker socket access carries **serious security implications** (see the warning above). You are solely responsible for evaluating those risks, securing your environment, and deciding whether this approach is appropriate for your use case.
- This project is **not affiliated with, endorsed by, or supported by Prefect Technologies, Inc.** "Prefect" is a trademark of its respective owner and is used here for descriptive purposes only.
- No guarantee is made regarding correctness, security, or continued maintenance. Container images may contain upstream vulnerabilities at any point in time; you are responsible for scanning and patching as needed.
- By using this project, you acknowledge that you have read and understood this disclaimer and accept full responsibility for your use of it.

## License

MIT
