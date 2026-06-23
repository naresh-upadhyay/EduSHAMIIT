output "cloud_run_service_name" {
  description = "Name of the Cloud Run service"
  value       = google_cloud_run_v2_service.main.name
}

output "cloud_run_service_url" {
  description = "URL of the deployed Cloud Run service"
  value       = google_cloud_run_v2_service.main.uri
}

output "cloud_run_service_location" {
  description = "Region where the service is deployed"
  value       = google_cloud_run_v2_service.main.location
}

output "artifact_registry_repository" {
  description = "Artifact Registry repository for Docker images"
  value       = google_artifact_registry_repository.main.name
}

output "artifact_registry_image_path" {
  description = "Full Docker image path"
  value       = "${google_artifact_registry_repository.main.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.main.repository_id}/${var.image_name}"
}

output "service_account_cloud_run" {
  description = "Cloud Run service account email"
  value       = google_service_account.cloud_run.email
}

output "service_account_github_actions" {
  description = "GitHub Actions deployer service account email (request key for CI/CD)"
  value       = google_service_account.github_actions.email
}

output "gcs_bucket_name" {
  description = "GCS bucket for file uploads"
  value       = var.create_gcs_bucket ? google_storage_bucket.uploads[0].name : ""
}