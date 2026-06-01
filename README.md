# Nilabiru Data Hub Agent

A lightweight companion stack for the [Nilabiru Data Hub](https://github.com/andry-pebrianto/nilabiru-data-hub), designed to be deployed on a separate server and connected back to the main hub for centralized Docker management and secure remote access via Tailscale.

---

## Overview

**Nilabiru Data Hub Agent** provisions two services on a remote server — a Portainer Agent that registers itself to the Portainer instance running on the main Nilabiru Data Hub, and a Tailscale VPN tunnel to ensure secure connectivity between the two nodes. Deployments are fully automated via GitHub Actions on every push to `main`.

---

## Architecture

```
┌─────────────────────────────┐        Tailscale VPN         ┌─────────────────────────────┐
│     Nilabiru Data Hub       │ ◄──────────────────────────► │   Nilabiru Data Hub Agent   │
│                             │                              │                             │
│  • Portainer (server)  9443 │                              │  • Portainer Agent     9001 │
│  • Redis, PostgreSQL, etc.  │                              │  • Tailscale                │
└─────────────────────────────┘                              └─────────────────────────────┘
```

The Portainer server on the main hub manages this agent remotely by connecting to it as an **Agent** environment over the Tailscale network.

---

## Services

| Service             | Image                        | Port(s) | Description                                                        |
| ------------------- | ---------------------------- | ------- | ------------------------------------------------------------------ |
| **Portainer Agent** | `portainer/agent:latest`     | `9001`  | Exposes the local Docker engine to the Portainer server on the hub |
| **Tailscale**       | `tailscale/tailscale:latest` | —       | VPN tunnel for secure connectivity back to the main hub            |

Portainer Agent is connected to a bridge network named `nilabiru-data-hub-agent`. Tailscale uses `host` network mode.

---

## Requirements

- Docker Engine `20.10+`
- Docker Compose `v2+`
- A [Tailscale](https://tailscale.com) account with an auth key (same tailnet as the main hub)
- The main **Nilabiru Data Hub** already running with Portainer accessible at `https://nilabiru-data-hub:9443`

---

## Getting Started

### 1. Clone the repository

```bash
git clone https://github.com/andry-pebrianto/nilabiru-data-hub-agent.git
cd nilabiru-data-hub-agent
```

### 2. Configure environment variables

Copy the provided `env` file and fill in all values:

```bash
cp env .env
```

Then edit `.env`:

```env
# Tailscale
TAILSCALE_AUTHKEY=tskey-auth-xxxxx
TS_HOSTNAME=nilabiru-data-hub-agent
```

> **Note:** Never commit `.env` to version control. It is already listed in `.gitignore`.

### 3. Start the stack

```bash
docker compose up -d
```

To verify all services are running:

```bash
docker compose ps
```

---

## Connecting to the Main Hub

Once this agent is running and reachable over Tailscale, register it in the Portainer instance on the main hub:

1. Open Portainer on the main hub at `https://nilabiru-data-hub:9443`
2. Go to **Environments → Add environment**
3. Select **Agent**
4. Set the environment URL to `nilabiru-data-hub-agent:9001`
5. Save — the agent server will now appear in Portainer's environment list

---

## Service Access

| Service         | URL / Address                                  |
| --------------- | ---------------------------------------------- |
| Portainer Agent | `localhost:9001`                               |
| Portainer Agent | `nilabiru-data-hub-agent:9001` (via Tailscale) |

---

## Data Persistence

| Volume           | Service   |
| ---------------- | --------- |
| `tailscale-data` | Tailscale |

The Portainer Agent mounts the Docker socket and volumes directory from the host directly and does not require a named volume.

---

## CI/CD Deployment

This project uses GitHub Actions for continuous deployment. On every push to the `main` branch, the workflow:

1. Checks out the latest code and pulls from `origin main` on the self-hosted runner.
2. Validates the Compose configuration with `docker compose config`.
3. Restarts all services with `docker compose up -d --remove-orphans`.
4. Polls container status every 10 seconds, up to a maximum of 180 seconds.
5. Exits successfully once all containers are `running`; fails with a list of unhealthy containers if the timeout is reached.

The workflow file is located at `.github/workflows/deploy.yml`. A self-hosted GitHub Actions runner must be configured on the target server for this to work.

---

## Health Checks

Neither Portainer Agent nor Tailscale define Docker health checks by default, so the CI/CD health check step treats a `running` status with `health: none` as passing.

---

## License

This project is licensed under the [MIT License](LICENSE).  
Copyright © 2026 Andry Pebrianto
