resource "google_cloud_run_v2_service" "main" {
  name     = var.service_name
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    timeout           = "${var.timeout_seconds}s"
    max_instance_request_concurrency = var.concurrency

    service_account = google_service_account.cloud_run.email

    containers {
      name  = var.service_name
      image = "${google_artifact_registry_repository.main.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.main.repository_id}/${var.image_name}:${var.image_tag}"

      ports {
        container_port = var.container_port
      }

      resources {
        cpu_idle          = true
        startup_cpu_boost = true

        limits = {
          cpu    = var.cpu
          memory = var.memory
        }
      }

      # Plain text env vars
      dynamic "env" {
        for_each = var.env_vars
        content {
          name  = env.key
          value = env.value
        }
      }

      # Secret env vars
      dynamic "env" {
        for_each = var.database_url_secret_id != "" ? [1] : []
        content {
          name = "DATABASE_URL"
          value_source {
            secret_key_ref {
              secret  = var.database_url_secret_id
              version = "latest"
            }
          }
        }
      }

      dynamic "env" {
        for_each = var.supabase_url_secret_id != "" ? [1] : []
        content {
          name = "SUPABASE_URL"
          value_source {
            secret_key_ref {
              secret  = var.supabase_url_secret_id
              version = "latest"
            }
          }
        }
      }

      dynamic "env" {
        for_each = var.jwt_secret_secret_id != "" ? [1] : []
        content {
          name = "SUPABASE_JWT_SECRET"
          value_source {
            secret_key_ref {
              secret  = var.jwt_secret_secret_id
              version = "latest"
            }
          }
        }
      }

      dynamic "env" {
        for_each = var.redis_url_secret_id != "" ? [1] : []
        content {
          name = "REDIS_URL"
          value_source {
            secret_key_ref {
              secret  = var.redis_url_secret_id
              version = "latest"
            }
          }
        }
      }

      dynamic "env" {
        for_each = var.openai_api_key_secret_id != "" ? [1] : []
        content {
          name = "OPENAI_API_KEY"
          value_source {
            secret_key_ref {
              secret  = var.openai_api_key_secret_id
              version = "latest"
            }
          }
        }
      }

      dynamic "env" {
        for_each = var.secret_env_vars
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = env.value
              version = "latest"
            }
          }
        }
      }

      startup_probe {
        initial_delay_seconds = 5
        timeout_seconds       = 5
        period_seconds        = 10
        failure_threshold     = 3

        http_get {
          path = "/health"
          port = var.container_port
        }
      }

      liveness_probe {
        http_get {
          path = "/health"
          port = var.container_port
        }
        initial_delay_seconds = 15
        period_seconds        = 30
      }
    }

    # VPC access (optional — for connecting to managed Redis/DB)
    # vpc_access {
    #   connector = google_vpc_access_connector.main.id
    #   egress    = "PRIVATE_RANGES_ONLY"
    # }
  }

  lifecycle {
    ignore_changes = [
      template[0].containers[0].image,
    ]
  }
}

# Allow unauthenticated invocations (optional — enable if behind API gateway)
resource "google_cloud_run_v2_service_iam_member" "public_invoke" {
  count    = var.domain != "" ? 1 : 0
  location = google_cloud_run_v2_service.main.location
  name     = google_cloud_run_v2_service.main.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}