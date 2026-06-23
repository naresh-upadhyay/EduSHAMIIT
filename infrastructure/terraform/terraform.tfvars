project_id     = "project-7ae4e5e7-5fb3-4dc7-809"
region         = "us-central1"
service_name   = "edushamiit-api"
image_name     = "edushamiit-api"
image_tag      = "latest"
min_instances  = 0
max_instances  = 3
concurrency    = 80
cpu            = "1"
memory         = "512Mi"
timeout_seconds = 300
container_port = 8000
create_gcs_bucket = true
gcs_bucket_location = "US"

# Plain text env vars for Cloud Run (no secrets configured yet)
env_vars = {
  ENVIRONMENT     = "production"
  DEBUG           = "false"
  APP_ENV         = "production"
  JWT_ALGORITHM   = "HS256"
}

# No secrets configured yet — set these up in Secret Manager later
database_url_secret_id   = ""
supabase_url_secret_id   = ""
jwt_secret_secret_id     = ""
redis_url_secret_id      = ""
openai_api_key_secret_id = ""