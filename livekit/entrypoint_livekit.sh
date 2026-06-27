#!/bin/sh

# Default keys
API_KEY="${LIVEKIT_API_KEY:-devkey}"
API_SECRET="${LIVEKIT_API_SECRET:-secretkey_edushamiit_livekit_2026_secure}"

# Defaults for Redis
REDIS_HOST="redis"
REDIS_PORT="6379"
REDIS_PASSWORD="redis_password_2026"
IS_TLS="false"

# Parse Redis URL if provided
if [ ! -z "$REDIS_URL" ]; then
  case "$REDIS_URL" in
    rediss://*)
      IS_TLS="true"
      ;;
  esac

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

# Write custom livekit.yaml configuration
cat <<EOF > /livekit.yaml
port: ${PORT:-8080}
bind_addresses:
  - ""
rtc:
  tcp_port: 7881
  port_range_start: 50000
  port_range_end: 50050
  use_external_ip: ${USE_EXTERNAL_IP:-true}
  enable_loopback_candidate: true
EOF

if [ ! -z "$REDIS_PASSWORD" ]; then
cat <<EOF >> /livekit.yaml
redis:
  address: "${REDIS_HOST}:${REDIS_PORT}"
  password: "${REDIS_PASSWORD}"
EOF
else
cat <<EOF >> /livekit.yaml
redis:
  address: "${REDIS_HOST}:${REDIS_PORT}"
EOF
fi

if [ "$IS_TLS" = "true" ]; then
cat <<EOF >> /livekit.yaml
  use_tls: true
  tls:
    enabled: true
EOF
fi

cat <<EOF >> /livekit.yaml
keys:
  "${API_KEY}": "${API_SECRET}"
logging:
  level: info
EOF

echo "Starting LiveKit Server on port ${PORT:-8080}..."
exec /livekit-server --config /livekit.yaml
