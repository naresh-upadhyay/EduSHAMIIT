# EduSHAMIIT – Makefile
# Usage: make <target>

.PHONY: up down reset logs ps shell-db shell-redis build pull clean help

# ── Primary commands ───────────────────────────────────────────

## Start everything (build images first)
up:
	docker compose up -d --build

## Start without rebuilding images
start:
	docker compose up -d

## Stop all services (keep volumes)
down:
	docker compose down

## Full reset – wipe all data volumes and restart fresh
reset:
	docker compose down -v
	docker compose up -d --build

## Stop and remove containers + volumes + orphans
destroy:
	docker compose down -v --remove-orphans

# ── Monitoring ────────────────────────────────────────────────

## Tail logs for all services
logs:
	docker compose logs -f

## Tail logs for a specific service  e.g.: make logs-db
logs-%:
	docker compose logs -f $*

## Show running containers and health status
ps:
	docker compose ps

## Show resource usage
stats:
	docker stats --no-stream

# ── Build ─────────────────────────────────────────────────────

## Rebuild FastAPI image only
build:
	docker compose build api

## Pull latest images for all services
pull:
	docker compose pull

# ── Database ──────────────────────────────────────────────────

## Open psql shell inside the Postgres container
shell-db:
	docker exec -it supabase-db psql -U postgres -d postgres

## Show table count in public schema
db-tables:
	docker exec supabase-db psql -U postgres -d postgres -c \
	  "SELECT COUNT(*) AS tables FROM information_schema.tables WHERE table_schema='public';"

## Show function count in public schema
db-functions:
	docker exec supabase-db psql -U postgres -d postgres -c \
	  "SELECT COUNT(*) AS functions FROM information_schema.routines WHERE routine_schema='public';"

# ── Redis ─────────────────────────────────────────────────────

## Open redis-cli inside the Redis container
shell-redis:
	docker exec -it edushamiit-redis redis-cli -a $(shell grep REDIS_PASSWORD .env | cut -d= -f2)

# ── Cleanup ───────────────────────────────────────────────────

## Remove dangling images and build cache
clean:
	docker image prune -f
	docker builder prune -f

# ── Help ──────────────────────────────────────────────────────

help:
	@echo ""
	@echo "  EduSHAMIIT Docker Commands"
	@echo "  ─────────────────────────────────────────────────"
	@echo "  make up           Build & start everything"
	@echo "  make start        Start without rebuilding"
	@echo "  make down         Stop all services (keep data)"
	@echo "  make reset        Wipe data + restart fresh"
	@echo "  make destroy      Remove everything including volumes"
	@echo "  make logs         Tail all logs"
	@echo "  make logs-<svc>   Tail logs for specific service"
	@echo "  make ps           Show container status"
	@echo "  make stats        Show resource usage"
	@echo "  make build        Rebuild FastAPI images only"
	@echo "  make pull         Pull latest Docker images"
	@echo "  make shell-db     Open psql in Postgres"
	@echo "  make db-tables    Count tables in public schema"
	@echo "  make db-functions Count functions in public schema"
	@echo "  make shell-redis  Open redis-cli"
	@echo "  make clean        Remove dangling images/cache"
	@echo ""
	@echo "  Ports:"
	@echo "    :80     → FastAPI (Nginx reverse proxy)"
	@echo "    :8000   → Supabase Kong (REST/Auth/Storage/Realtime)"
	@echo "    :54323  → Supabase Studio"
	@echo "    :5432   → PostgreSQL"
	@echo "    :6379   → Redis"
	@echo "    :1883   → MQTT (Mosquitto)"
	@echo "    :9001   → MQTT over WebSockets"
	@echo "    :6543   → Supavisor (connection pooler)"
	@echo ""
