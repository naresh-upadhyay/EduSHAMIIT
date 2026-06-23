resource "google_artifact_registry_repository" "main" {
  location      = var.region
  repository_id = "${var.service_name}-repo"
  description   = "Docker repository for EduSHAMIIT API"
  format        = "DOCKER"

  cleanup_policy_dry_run = false

  cleanup_policies {
    id     = "keep-recent"
    action = "KEEP"
    most_recent_versions {
      keep_count = 5
    }
  }

  cleanup_policies {
    id     = "delete-untagged"
    action = "DELETE"
    condition {
      tag_state = "UNTAGGED"
      older_than = "43200s"
    }
  }
}