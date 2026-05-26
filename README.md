# nilabiru-data-hub

A self-hosted data infrastructure stack for the Nilabiru ecosystem, bundling essential data services into a single Docker Compose setup with automated CI/CD deployment and secure remote access via Tailscale.

---

## Overview

**nilabiru-data-hub** provisions and manages a cohesive set of data infrastructure services — cache, relational databases, document store, message broker, object storage, workflow automation, and container management — all running in isolated Docker containers on a shared internal network. Remote access is secured through a Tailscale VPN tunnel, and deployments are fully automated via GitHub Actions on every push to `main`.

---

## Services

| Service        | Image                           | Port(s)         | Description                                                                                  |
| -------------- | ------------------------------- | --------------- | -------------------------------------------------------------------------------------------- |
| **Redis**      | `redis:7-alpine`                | `6379`          | In-memory cache and key-value store with password protection                                 |
| **PostgreSQL** | `postgres:16-alpine`            | `5432`          | Relational database with configurable user, password, and database name                      |
| **MySQL**      | `mysql:8-debian`                | `3306`          | Relational database with root and non-root user support                                      |
| **MongoDB**    | `mongo:7`                       | `27017`         | Document-oriented NoSQL database with root authentication                                    |
| **RabbitMQ**   | `rabbitmq:3-management-alpine`  | `5672`, `15672` | Message broker with management UI available at port `15672`                                  |
| **RustFS**     | `rustfs/rustfs:latest`          | `9000`, `9001`  | High-performance S3-compatible object storage (Apache 2.0); console available at port `9001` |
| **n8n**        | `n8nio/n8n:latest`              | `5678`          | Self-hosted workflow automation, backed by PostgreSQL                                        |
| **Portainer**  | `portainer/portainer-ce:latest` | `9443`, `8000`  | Web-based Docker management dashboard                                                        |
| **Tailscale**  | `tailscale/tailscale`           | —               | VPN tunnel for secure remote access to the stack                                             |

All services (except Tailscale, which uses `host` network mode) are connected through a shared bridge network named `nilabiru-data-hub`.

---

## Requirements

- Docker Engine `20.10+`
- Docker Compose `v2+`
- A [Tailscale](https://tailscale.com) account with an auth key
- A server with a mounted SATA drive at `/sata-storage` (used by RustFS)

---

## Getting Started

### 1. Clone the repository

```bash
git clone https://github.com/<your-username>/nilabiru-data-hub.git
cd nilabiru-data-hub
```

### 2. Configure environment variables

Copy the provided `env` file and fill in all values:

```bash
cp env .env
```

Then edit `.env`:

```env
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

# n8n
N8N_ENCRYPTION_KEY=your_random_32_char_string
N8N_DB_NAME=n8n
N8N_HOST=localhost
N8N_PROTOCOL=http

# Tailscale
TAILSCALE_AUTHKEY=tskey-auth-xxxxx
```

> **Note:** Never commit `.env` to version control. It is already listed in `.gitignore`.

### 3. Prepare RustFS data directory

```bash
mkdir -p /sata-storage/rustfs-data
```

### 4. Create n8n database in PostgreSQL

n8n uses PostgreSQL as its database. Create the database before starting the stack:

```bash
docker compose up -d nilabiru-postgres
docker exec -it nilabiru-postgres psql -U $POSTGRES_USER -c "CREATE DATABASE n8n;"
```

### 5. Start the stack

```bash
docker compose up -d
```

To verify all services are healthy:

```bash
docker compose ps
```

---

## Service Access

| Service             | URL / Address            |
| ------------------- | ------------------------ |
| Redis               | `localhost:6379`         |
| PostgreSQL          | `localhost:5432`         |
| MySQL               | `localhost:3306`         |
| MongoDB             | `localhost:27017`        |
| RabbitMQ AMQP       | `localhost:5672`         |
| RabbitMQ Management | `http://localhost:15672` |
| RustFS API          | `http://localhost:9000`  |
| RustFS Console      | `http://localhost:9001`  |
| n8n                 | `http://localhost:5678`  |
| Portainer           | `https://localhost:9443` |

When Tailscale is active, all services are also reachable via the Tailscale network at the hostname `nilabiru-data-hub`. 

---

## Data Persistence

Persistent volumes are defined for each stateful service:

| Volume                      | Service                         |
| --------------------------- | ------------------------------- |
| `redis-data`                | Redis                           |
| `postgres-data`             | PostgreSQL                      |
| `mysql-data`                | MySQL                           |
| `mongodb-data`              | MongoDB                         |
| `rabbitmq-data`             | RabbitMQ                        |
| `/sata-storage/rustfs-data` | RustFS (host bind mount — data) |
| `rustfs-logs`               | RustFS (logs)                   |
| `n8n-data`                  | n8n                             |
| `portainer-data`            | Portainer                       |
| `tailscale-data`            | Tailscale                       |

---

## CI/CD Deployment

This project uses GitHub Actions for continuous deployment. On every push to the `main` branch, the workflow:

1. Checks out the latest code on the self-hosted runner.
2. Pulls the latest changes from `origin main`.
3. Restarts all services with `docker compose up -d --remove-orphans`.
4. Runs a health check verifying all containers are in `running` state.
5. If any container is not running, the workflow fails and GitHub sends an email notification automatically.

The workflow file is located at `.github/workflows/deploy.yml`. A self-hosted GitHub Actions runner must be configured on the target server for this to work.

---

## Health Checks

All critical services include Docker health checks to ensure availability:

- **Redis** — `redis-cli ping`
- **PostgreSQL** — `pg_isready`
- **MySQL** — `mysqladmin ping`
- **MongoDB** — `mongosh db.adminCommand('ping')`
- **RabbitMQ** — `rabbitmq-diagnostics ping`
- **RustFS** — `curl http://localhost:9000/health` & `curl http://localhost:9001/rustfs/console/health`
- **n8n** — `wget http://localhost:5678/healthz`

---

## License

This project is licensed under the [MIT License](LICENSE).  
Copyright © 2022 Andry Pebrianto
