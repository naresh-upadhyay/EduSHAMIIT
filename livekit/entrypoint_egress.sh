#!/bin/sh

# Start the simple health check server in the background
python3 /health.py &

# Default keys
API_KEY="${LIVEKIT_API_KEY:-devkey}"
API_SECRET="${LIVEKIT_API_SECRET:-secretkey_edushamiit_livekit_2026_secure}"

# Defaults for Redis
REDIS_HOST="redis"
REDIS_PORT="6379"
REDIS_PASSWORD="redis_password_2026"

# Parse Redis URL if provided
if [ ! -z "$REDIS_URL" ]; then
  # Strip prefix
  REDIS_CLEAN="${REDIS_URL#*://}"
  
  # If there is a password (contains '@')
  case "$REDIS_CLEAN" in
    *@*)
      REDIS_AUTH="${REDIS_CLEAN%%@*}"
      REDIS_HOST_PORT="${REDIS_CLEAN#*@}"
      
      # Extract password (everything after ':')
      case "$REDIS_AUTH" in
        *:*)
          REDIS_PASSWORD="${REDIS_AUTH#*:}"
          ;;
        *)
          REDIS_PASSWORD="$REDIS_AUTH"
          ;;
      esac
      ;;
    *)
      REDIS_HOST_PORT="$REDIS_CLEAN"
      REDIS_PASSWORD=""
      ;;
  esac
  
  # Extract host and port
  case "$REDIS_HOST_PORT" in
    *:*)
      REDIS_HOST="${REDIS_HOST_PORT%%:*}"
      REDIS_PORT="${REDIS_HOST_PORT#*:}"
      ;;
    *)
      REDIS_HOST="$REDIS_HOST_PORT"
      REDIS_PORT="6379"
      ;;
  esac
fi

# Write dynamic egress.yaml configuration
cat <<EOF > /egress.yaml
api_key: "${API_KEY}"
api_secret: "${API_SECRET}"
ws_url: "${LIVEKIT_WS_URL:-ws://livekit:7880}"
insecure: true
log_level: "info"
enable_chrome_sandbox: false
template_base: "${TEMPLATE_BASE:-http://localhost:7980}"

cpu_cost:
  room_composite_cpu_cost: 3.0

chrome_extra_args:
  - "--no-sandbox"
  - "--disable-setuid-sandbox"
  - "--disable-extensions"
  - "--disable-gpu"
  - "--use-gl=swiftshader"
  - "--disable-dev-shm-usage"
  - "--autoplay-policy=no-user-gesture-required"
  - "--disable-background-timer-throttling"
  - "--disable-renderer-backgrounding"
  - "--disable-backgrounding-occluded-windows"
  - "--disable-ipc-flooding-protection"
EOF

if [ ! -z "$REDIS_PASSWORD" ]; then
cat <<EOF >> /egress.yaml
redis:
  address: "${REDIS_HOST}:${REDIS_PORT}"
  password: "${REDIS_PASSWORD}"
EOF
else
cat <<EOF >> /egress.yaml
redis:
  address: "${REDIS_HOST}:${REDIS_PORT}"
EOF
fi

# Add S3 storage settings if configured
if [ ! -z "$S3_BUCKET" ] || [ ! -z "$AWS_BUCKET" ]; then
cat <<EOF >> /egress.yaml
s3:
  access_key: "${S3_ACCESS_KEY:-${AWS_ACCESS_KEY_ID:-minio_admin}}"
  secret: "${S3_SECRET:-${AWS_SECRET_ACCESS_KEY:-minio_password_2026}}"
  region: "${S3_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"
  endpoint: "${S3_ENDPOINT:-http://minio:9000}"
  bucket: "${S3_BUCKET:-${AWS_BUCKET:-live-classes}}"
  force_path_style: true
EOF
fi

echo "Starting LiveKit Egress Service..."
exec /egress --config /egress.yaml
