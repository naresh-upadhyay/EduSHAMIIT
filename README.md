# EduSHAMIIT – Single Command Deployment

Deploy the **complete EduSHAMIIT stack** with one command.

## Quick Start

```bash
# 1. Copy env template and fill in your secrets
cp .env.example .env

# 2. Launch everything
docker compose up -d --build
```

That's it. All 91 database migrations run automatically on first boot.

---

## What Starts

| Service | Image | Port(s) | Purpose |
|---|---|---|---|
| `db` | `supabase/postgres:15.8.1` | 5432 | PostgreSQL + pgvector + all Supabase schemas |
| `auth` | `supabase/gotrue:v2.186.0` | — | Auth / JWT / OTP |
| `rest` | `postgrest/postgrest:v14.8` | — | Auto REST API from DB schema |
| `realtime` | `supabase/realtime:v2.76.5` | — | WebSocket DB subscriptions |
| `storage` | `supabase/storage-api:v1.48.26` | — | File / object storage |
| `imgproxy` | `darthsim/imgproxy:v3.30.1` | — | Image transforms |
| `meta` | `supabase/postgres-meta:v0.96.3` | — | DB introspection for Studio |
| `analytics` | `supabase/logflare:1.36.1` | — | Log aggregation |
| `vector` | `timberio/vector:0.53.0` | — | Log shipping to analytics |
| `supavisor` | `supabase/supavisor:2.7.4` | 6543 | Connection pooler |
| `kong` | `kong/kong:3.9.1` | **8000** | API Gateway |
| `studio` | `supabase/studio:2026.04.08` | **54323** | Dashboard UI |
| `redis` | `redis:7-alpine` | 6379 | Caching / sessions |
| `rabbitmq` | `rabbitmq:3-management` | 5672 / **15672** | Task queue |
| `mosquitto` | `eclipse-mosquitto:2` | 1883 / 9001 | MQTT / IoT |
| `api-1/2/3` | Built locally | — | FastAPI replicas |
| `nginx` | `nginx:alpine` | **80** | Load balancer |

---

## Access URLs

| UI | URL | Credentials |
|---|---|---|
| FastAPI | http://localhost/docs | — |
| FastAPI Health | http://localhost/health | — |
| Supabase Kong | http://localhost:8000 | — |
| Supabase Studio | http://localhost:54323 | `DASHBOARD_USERNAME` / `DASHBOARD_PASSWORD` from `.env` |
| RabbitMQ UI | http://localhost:15672 | `RABBITMQ_USER` / `RABBITMQ_PASSWORD` from `.env` |

---

## Common Commands

```bash
# Start everything
docker compose up -d --build

# Stop (keep data)
docker compose down

# Wipe all data and restart fresh
docker compose down -v && docker compose up -d --build

# View logs
docker compose logs -f

# View logs for one service
docker compose logs -f api-1

# Open Postgres shell
docker exec -it supabase-db psql -U postgres -d postgres

# Check migration ran correctly
docker exec supabase-db psql -U postgres -d postgres \
  -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public';"

# Container status + health
docker compose ps
```

Or use the **Makefile** shortcuts: `make help`

---

## Directory Structure

```
EduSHAMIIT/
├── docker-compose.yml              ← Single unified stack
├── .env                            ← All secrets (DO NOT COMMIT)
├── .env.example                    ← Safe template to commit
├── Makefile                        ← Convenience commands
│
├── volumes/
│   ├── db/                         ← Supabase init SQL (auto-mounted)
│   │   ├── jwt.sql
│   │   ├── roles.sql
│   │   ├── webhooks.sql
│   │   ├── realtime.sql
│   │   ├── _supabase.sql
│   │   ├── logs.sql
│   │   └── pooler.sql
│   ├── api/
│   │   ├── kong.yml                ← Kong declarative config
│   │   └── kong-entrypoint.sh     ← Kong startup script
│   ├── logs/
│   │   └── vector.yml             ← Vector log shipper config
│   └── pooler/
│       └── pooler.exs             ← Supavisor init script
│
├── mosquitto/
│   └── mosquitto.conf             ← MQTT broker config
│
├── nginx/
│   └── nginx.conf                 ← Load balancer config
│
├── EduSHAMIIT Backend/
│   └── backend/                   ← FastAPI app (built by Docker)
│
└── EduSHAMIIT Database/
    └── edushamiit-db/
        └── migrations/            ← 91 SQL files (auto-run on first boot)
```

---

## How Migrations Work

The `migrations/` folder is mounted into `/docker-entrypoint-initdb.d/migrations/app/` inside the Postgres container. Docker runs all `.sql` files there **automatically on first boot** — in alphabetical order (001 → 091). No manual steps needed.

> **Re-running:** All migrations use `CREATE ... IF NOT EXISTS` so they are fully idempotent. To force a full re-run, use `docker compose down -v` to wipe the volume, then `docker compose up -d`.

---

## Production Checklist

- [ ] Replace all placeholder secrets in `.env`
- [ ] Generate new `ANON_KEY` and `SERVICE_ROLE_KEY` JWTs signed with your `JWT_SECRET`
- [ ] Set `ENABLE_EMAIL_AUTOCONFIRM=false` for production
- [ ] Set `DEBUG=false` and `ENVIRONMENT=production`
- [ ] Configure real SMTP credentials
- [ ] Set `allow_anonymous false` in `mosquitto/mosquitto.conf` and add a password file
- [ ] Put Nginx behind a reverse proxy (Caddy/Traefik) with TLS for production
