# Nilabiru Data Hub

A self-hosted data infrastructure stack for the Nilabiru ecosystem, bundling essential data services into a single Docker Compose setup with automated CI/CD deployment.

---

## Overview

**Nilabiru Data Hub** provisions and manages a cohesive set of data infrastructure services — reverse proxy, FRP client, cache, relational databases, document store, message broker, object storage, file management, and container management — all running in isolated Docker containers on a shared internal network. Deployments are fully automated via GitHub Actions on every push to `main`.

---

## Services

| Service                          | Image                             | Port(s)           | Description                                                                                                               |
| -------------------------------- | --------------------------------- | ----------------- | ------------------------------------------------------------------------------------------------------------------------- |
| **nilabiru-nginx-proxy-manager** | `jc21/nginx-proxy-manager:2.15.1` | `80`, `443`, `81` | Reverse proxy and SSL/TLS certificate management, with a web-based admin UI on port `81`                                  |
| **nilabiru-frpc**                | `fatedier/frpc:v0.69.1`           | —                 | FRP client that tunnels traffic through an FRP server; configured via `frpc.toml`                                         |
| **nilabiru-redis**               | `redis:8.8-alpine`                | `6379`            | In-memory cache and key-value store with password protection                                                              |
| **nilabiru-postgres**            | `postgres:17-alpine`              | `5432`            | Relational database with configurable user, password, and database name                                                   |
| **nilabiru-mongodb**             | `mongo:8.0.11`                    | `27017`           | Document-oriented NoSQL database with root authentication                                                                 |
| **nilabiru-rabbitmq**            | `rabbitmq:4.1-management-alpine`  | `5672`, `15672`   | Message broker with management UI available at port `15672`                                                               |
| **nilabiru-rustfs**              | `rustfs/rustfs:latest`            | `9000`, `9001`    | High-performance S3-compatible object storage (Apache 2.0); console available at port `9001`                              |
| **nilabiru-nextcloud**           | `nextcloud:29-apache`             | `8080`            | Self-hosted file management and cloud storage, backed by PostgreSQL and Redis, served behind the reverse proxy over HTTPS |
| **nilabiru-portainer**           | `portainer/portainer-ce:2.42.0`   | `9443`, `8000`    | Web-based Docker management dashboard                                                                                     |

All services are connected through a shared bridge network named `nilabiru-data-hub`. With the exception of Nginx Proxy Manager's HTTP/HTTPS ports (`80`, `443`), which are exposed on all network interfaces to allow public traffic and SSL certificate issuance, every other port — including the Nginx Proxy Manager admin UI (`81`) — is bound to the Tailscale IP (`TAILSCALE_IP`) for secure private network access only. The **nilabiru-frpc** service exposes no host ports directly; it tunnels traffic through the configured FRP server.

---

## Requirements

- Docker Engine `20.10+`
- Docker Compose `v2+`
- A server with a mounted SATA drive at `/sata-storage` (used by RustFS and Nextcloud)
- Tailscale installed and connected on the server and all client machines
- Ports `80` and `443` open/forwarded on the host (used by Nginx Proxy Manager for reverse proxying and SSL certificate issuance)
- A running FRP server reachable at `FRP_SERVER_ADDR` (used by the frpc service)

---

## Getting Started

### 1. Clone the repository

```bash
git clone https://github.com/andry-pebrianto/nilabiru-data-hub.git
cd nilabiru-data-hub
```

### 2. Configure environment variables

Copy the provided `env` file and fill in all values:

```bash
cp env .env
```

Then edit `.env`:

```env
# Tailscale
TAILSCALE_IP=your_tailscale_ip

# FRP
FRP_SERVER_ADDR=your_frp_server_address
FRP_TOKEN=your_frp_token

# Redis
REDIS_PASSWORD=your_redis_password

# PostgreSQL
POSTGRES_USER=your_postgres_user
POSTGRES_PASSWORD=your_postgres_password
POSTGRES_DB=your_database_name

# MongoDB
MONGO_ROOT_USERNAME=your_mongo_root_username
MONGO_ROOT_PASSWORD=your_mongo_root_password

# RabbitMQ
RABBITMQ_USER=your_rabbitmq_user
RABBITMQ_PASSWORD=your_rabbitmq_password
RABBITMQ_VHOST=/

# RustFS
RUSTFS_ACCESS_KEY=your_rustfs_access_key
RUSTFS_SECRET_KEY=your_rustfs_secret_key

# Nextcloud
NEXTCLOUD_DB_NAME=nextcloud
NEXTCLOUD_ADMIN_USER=your_nextcloud_admin_username
NEXTCLOUD_ADMIN_PASSWORD=your_nextcloud_admin_password
NEXTCLOUD_TRUSTED_DOMAINS=your_nextcloud_trusted_domain
```

> **Note:** Never commit `.env` to version control. It is already listed in `.gitignore`.

> **Note:** This manual `.env` file is only needed for running `docker compose up -d` directly on the server. When deploying via the GitHub Actions workflow (see [CI/CD Deployment](#cicd-deployment)), the `.env` file is generated automatically on the runner from repository secrets — using the same variable names — and deleted again after each deploy.

### 3. Prepare the frpc configuration

Ensure `frpc.toml` exists in the repository root and is configured to connect to your FRP server. The `FRP_SERVER_ADDR` and `FRP_TOKEN` environment variables are passed into the container and should be referenced inside `frpc.toml` using FRP's environment variable expansion syntax:

```toml
serverAddr = "{{ .Envs.FRP_SERVER_ADDR }}"
auth.token = "{{ .Envs.FRP_TOKEN }}"
```

### 4. Prepare storage directories

```bash
mkdir -p /sata-storage/rustfs-data
mkdir -p /sata-storage/nextcloud-files
mkdir -p ./proxy-manager/data
mkdir -p ./proxy-manager/letsencrypt
```

### 5. Start the stack

```bash
docker compose up -d
```

The Nextcloud database is created automatically on first startup via `init-db.sh`, which runs as part of the PostgreSQL initialization process.

To verify all services are healthy:

```bash
docker compose ps
```

---

## Service Access

Most services are accessible only via the Tailscale IP of the server. The exception is Nginx Proxy Manager's ports `80` and `443`, which are exposed publicly to handle reverse-proxied traffic and SSL certificate issuance for any domains configured behind it.

| Service                        | URL / Address                 |
| ------------------------------ | ----------------------------- |
| Nginx Proxy Manager (Admin UI) | `http://<TAILSCALE_IP>:81`    |
| Redis                          | `<TAILSCALE_IP>:6379`         |
| PostgreSQL                     | `<TAILSCALE_IP>:5432`         |
| MongoDB                        | `<TAILSCALE_IP>:27017`        |
| RabbitMQ AMQP                  | `<TAILSCALE_IP>:5672`         |
| RabbitMQ Management            | `http://<TAILSCALE_IP>:15672` |
| RustFS API                     | `http://<TAILSCALE_IP>:9000`  |
| RustFS Console                 | `http://<TAILSCALE_IP>:9001`  |
| Nextcloud                      | `http://<TAILSCALE_IP>:8080`  |
| Portainer                      | `https://<TAILSCALE_IP>:9443` |

---

## Data Persistence

Persistent volumes and bind mounts are defined for each stateful service:

| Volume                          | Service                                              |
| ------------------------------- | ---------------------------------------------------- |
| `./proxy-manager/data`          | Nginx Proxy Manager (bind mount — config & database) |
| `./proxy-manager/letsencrypt`   | Nginx Proxy Manager (bind mount — SSL certificates)  |
| `./frpc.toml`                   | frpc (bind mount — read-only config)                 |
| `postgres-data`                 | PostgreSQL                                           |
| `./init-db.sh`                  | PostgreSQL (bind mount — initialization script)      |
| `redis-data`                    | Redis                                                |
| `mongodb-data`                  | MongoDB                                              |
| `rabbitmq-data`                 | RabbitMQ                                             |
| `/sata-storage/rustfs-data`     | RustFS (host bind mount — data)                      |
| `rustfs-logs`                   | RustFS (logs)                                        |
| `nextcloud-data`                | Nextcloud (app files)                                |
| `/sata-storage/nextcloud-files` | Nextcloud (user files — bind mount)                  |
| `/var/run/docker.sock`          | Portainer (bind mount — Docker socket access)        |
| `portainer-data`                | Portainer                                            |

---

## CI/CD Deployment

This project uses GitHub Actions for continuous deployment, running on a **self-hosted runner**. On every push to the `main` branch, the workflow at `.github/workflows/deploy.yml`:

1. Checks out the latest code on the self-hosted runner.
2. Generates a `.env` file on the runner from GitHub Actions secrets (the same variable names used in [Configure environment variables](#2-configure-environment-variables)).
3. Makes `init-db.sh` executable (`chmod +x init-db.sh`).
4. Validates the Compose configuration with `docker compose config`.
5. Deploys/redeploys all services with `docker compose up -d --remove-orphans`.
6. Removes the generated `.env` file from the runner (`rm -f .env`) — this cleanup step always runs, even if an earlier step fails, so secrets are never left on disk.

> **Note:** The workflow does not currently perform a post-deploy health check; it finishes as soon as `docker compose up -d` completes. Run `docker compose ps` on the server afterward to confirm every container is `running`/`healthy`.

A self-hosted GitHub Actions runner must be configured on the target server for this workflow to run.

### Required GitHub Secrets

Because the `.env` file is generated entirely from secrets at deploy time, the following repository secrets must be configured under **Settings → Secrets and variables → Actions**:

| Secret                      | Used by                     |
| --------------------------- | --------------------------- |
| `TAILSCALE_IP`              | All services (port binding) |
| `FRP_SERVER_ADDR`           | frpc                        |
| `FRP_TOKEN`                 | frpc                        |
| `REDIS_PASSWORD`            | Redis                       |
| `POSTGRES_USER`             | PostgreSQL, Nextcloud       |
| `POSTGRES_PASSWORD`         | PostgreSQL, Nextcloud       |
| `POSTGRES_DB`               | PostgreSQL                  |
| `MONGO_ROOT_USERNAME`       | MongoDB                     |
| `MONGO_ROOT_PASSWORD`       | MongoDB                     |
| `RABBITMQ_USER`             | RabbitMQ                    |
| `RABBITMQ_PASSWORD`         | RabbitMQ                    |
| `RABBITMQ_VHOST`            | RabbitMQ                    |
| `RUSTFS_ACCESS_KEY`         | RustFS                      |
| `RUSTFS_SECRET_KEY`         | RustFS                      |
| `NEXTCLOUD_DB_NAME`         | PostgreSQL, Nextcloud       |
| `NEXTCLOUD_ADMIN_USER`      | Nextcloud                   |
| `NEXTCLOUD_ADMIN_PASSWORD`  | Nextcloud                   |
| `NEXTCLOUD_TRUSTED_DOMAINS` | Nextcloud                   |

---

## License

This project is licensed under the [MIT License](LICENSE).  
Copyright © 2026 Andry Pebrianto