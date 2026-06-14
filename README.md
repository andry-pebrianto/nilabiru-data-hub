# Nilabiru Data Hub

A self-hosted data infrastructure stack for the Nilabiru ecosystem, bundling essential data services into a single Docker Compose setup with automated CI/CD deployment.

---

## Overview

**Nilabiru Data Hub** provisions and manages a cohesive set of data infrastructure services — cache, relational databases, document store, message broker, object storage, file management, and container management — all running in isolated Docker containers on a shared internal network. Deployments are fully automated via GitHub Actions on every push to `main`.

---

## Services

| Service        | Image                            | Port(s)         | Description                                                                                  |
| -------------- | -------------------------------- | --------------- | -------------------------------------------------------------------------------------------- |
| **Redis**      | `redis:8.8-alpine`               | `6379`          | In-memory cache and key-value store with password protection and memory limits               |
| **PostgreSQL** | `postgres:17-alpine`             | `5432`          | Relational database with configurable user, password, and database name                      |
| **MySQL**      | `mysql:8.4.9`                    | `3306`          | Relational database with root and non-root user support                                      |
| **MongoDB**    | `mongo:8.0`                      | `27017`         | Document-oriented NoSQL database with root authentication                                    |
| **RabbitMQ**   | `rabbitmq:4.1-management-alpine` | `5672`, `15672` | Message broker with management UI available at port `15672`                                  |
| **RustFS**     | `rustfs/rustfs:latest`           | `9000`, `9001`  | High-performance S3-compatible object storage (Apache 2.0); console available at port `9001` |
| **Nextcloud**  | `nextcloud:29-apache`            | `8080`          | Self-hosted file management and cloud storage, backed by PostgreSQL and Redis                |
| **Portainer**  | `portainer/portainer-ce:2.42.0`  | `9443`, `8000`  | Web-based Docker management dashboard                                                        |

All services are connected through a shared bridge network named `nilabiru-data-hub`. All ports are bound to the Tailscale IP (`TAILSCALE_IP`) for secure private network access only.

---

## Requirements

- Docker Engine `20.10+`
- Docker Compose `v2+`
- A server with a mounted SATA drive at `/sata-storage` (used by RustFS and Nextcloud)
- Tailscale installed and connected on the server and all client machines

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
TAILSCALE_IP=100.x.x.x

# Redis
REDIS_PASSWORD=your_redis_password

# PostgreSQL
POSTGRES_USER=your_postgres_user
POSTGRES_PASSWORD=your_postgres_password
POSTGRES_DB=your_database_name

# MySQL
MYSQL_ROOT_PASSWORD=your_mysql_root_password
MYSQL_USER=your_mysql_user
MYSQL_PASSWORD=your_mysql_password
MYSQL_DATABASE=your_mysql_database

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

### 3. Prepare storage directories

```bash
mkdir -p /sata-storage/rustfs-data
mkdir -p /sata-storage/nextcloud-files
```

### 4. Start the stack

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

All services are accessible only via the Tailscale IP of the server.

| Service             | URL / Address                 |
| ------------------- | ----------------------------- |
| Redis               | `<TAILSCALE_IP>:6379`         |
| PostgreSQL          | `<TAILSCALE_IP>:5432`         |
| MySQL               | `<TAILSCALE_IP>:3306`         |
| MongoDB             | `<TAILSCALE_IP>:27017`        |
| RabbitMQ AMQP       | `<TAILSCALE_IP>:5672`         |
| RabbitMQ Management | `http://<TAILSCALE_IP>:15672` |
| RustFS API          | `http://<TAILSCALE_IP>:9000`  |
| RustFS Console      | `http://<TAILSCALE_IP>:9001`  |
| Nextcloud           | `http://<TAILSCALE_IP>:8080`  |
| Portainer           | `https://<TAILSCALE_IP>:9443` |

---

## Data Persistence

Persistent volumes are defined for each stateful service:

| Volume                          | Service                             |
| ------------------------------- | ----------------------------------- |
| `redis-data`                    | Redis                               |
| `postgres-data`                 | PostgreSQL                          |
| `mysql-data`                    | MySQL                               |
| `mongodb-data`                  | MongoDB                             |
| `rabbitmq-data`                 | RabbitMQ                            |
| `/sata-storage/rustfs-data`     | RustFS (host bind mount — data)     |
| `rustfs-logs`                   | RustFS (logs)                       |
| `nextcloud-data`                | Nextcloud (app files)               |
| `/sata-storage/nextcloud-files` | Nextcloud (user files — bind mount) |
| `portainer-data`                | Portainer                           |

---

## CI/CD Deployment

This project uses GitHub Actions for continuous deployment. On every push to the `main` branch, the workflow:

1. Checks out the latest code on the self-hosted runner.
2. Validates the Compose configuration with `docker compose config`.
3. Restarts all services with `docker compose up -d --remove-orphans`.
4. Polls container status and health checks every 10 seconds, up to a maximum of 300 seconds.
5. Exits successfully once all containers are `running` and `healthy`; fails with a list of unhealthy containers if the timeout is reached.

The workflow file is located at `.github/workflows/deploy.yml`. A self-hosted GitHub Actions runner must be configured on the target server for this to work.

---

## Health Checks

All critical services include Docker health checks to ensure availability:

- **Redis** — `redis-cli -a $REDIS_PASSWORD ping`
- **PostgreSQL** — `pg_isready -U $POSTGRES_USER -d $POSTGRES_DB`
- **MySQL** — `mysqladmin ping -h localhost -u root -p$MYSQL_ROOT_PASSWORD`
- **MongoDB** — `mongosh --eval "db.adminCommand('ping')"`
- **RabbitMQ** — `rabbitmq-diagnostics ping`
- **RustFS** — `curl -f http://localhost:9000/health` and `curl -f http://localhost:9001/rustfs/console/health`
- **Nextcloud** — `curl -f http://localhost:80/status.php`
- **Portainer** — `wget --spider https://localhost:9443/api/system/status`

---

## License

This project is licensed under the [MIT License](LICENSE).  
Copyright © 2026 Andry Pebrianto
