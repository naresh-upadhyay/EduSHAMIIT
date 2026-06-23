resource "google_storage_bucket" "uploads" {
  count                        = var.create_gcs_bucket ? 1 : 0
  name                         = "${var.project_id}-${var.service_name}-uploads"
  location                     = var.gcs_bucket_location
  storage_class                = "STANDARD"
  uniform_bucket_level_access  = true
  force_destroy                = false
  public_access_prevention     = "enforced"

  versioning {
    enabled = false
  }

  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }

  labels = {
    service = var.service_name
    environment = "production"
  }
}