variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "service_name" {
  description = "Cloud Run service name"
  type        = string
  default     = "edushamiit-api"
}

variable "image_name" {
  description = "Docker image name in Artifact Registry"
  type        = string
  default     = "edushamiit-api"
}

variable "image_tag" {
  description = "Docker image tag"
  type        = string
  default     = "latest"
}

variable "cpu" {
  description = "CPU cores (0.5 - 4)"
  type        = string
  default     = "1"
}

variable "memory" {
  description = "Memory (256Mi - 4Gi)"
  type        = string
  default     = "512Mi"
}

variable "min_instances" {
  description = "Minimum instances (0 for free tier, 1 for no cold start)"
  type        = number
  default     = 0
}

variable "max_instances" {
  description = "Maximum instances to scale to"
  type        = number
  default     = 3
}

variable "concurrency" {
  description = "Max concurrent requests per instance"
  type        = number
  default     = 80
}

variable "container_port" {
  description = "Container port"
  type        = number
  default     = 8000
}

variable "timeout_seconds" {
  description = "Request timeout in seconds"
  type        = number
  default     = 300
}

variable "env_vars" {
  description = "Environment variables"
  type = map(string)
  default = {
    ENVIRONMENT     = "production"
    DEBUG           = "false"
    APP_ENV         = "production"
    JWT_ALGORITHM   = "HS256"
  }
}

variable "secret_env_vars" {
  description = "Secret environment variables (references to Secret Manager)"
  type = map(string)
  default = {}
}

variable "database_url_secret_id" {
  description = "Secret Manager ID for DATABASE_URL"
  type        = string
  default     = ""
}

variable "supabase_url_secret_id" {
  description = "Secret Manager ID for SUPABASE_URL"
  type        = string
  default     = ""
}

variable "jwt_secret_secret_id" {
  description = "Secret Manager ID for JWT_SECRET"
  type        = string
  default     = ""
}

variable "redis_url_secret_id" {
  description = "Secret Manager ID for REDIS_URL"
  type        = string
  default     = ""
}

variable "openai_api_key_secret_id" {
  description = "Secret Manager ID for OPENAI_API_KEY"
  type        = string
  default     = ""
}

variable "domain" {
  description = "Custom domain (optional)"
  type        = string
  default     = ""
}

variable "create_gcs_bucket" {
  description = "Create GCS bucket for file uploads"
  type        = bool
  default     = true
}

variable "gcs_bucket_location" {
  description = "GCS bucket location"
  type        = string
  default     = "US"
}

variable "schedule_db_migration" {
  description = "Schedule a Cloud Run job for DB migrations"
  type        = bool
  default     = false
}