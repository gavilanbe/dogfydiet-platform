output "microservice_1_service_account" {
  description = "Email of the microservice 1 service account"
  value       = google_service_account.microservice_1.email
}

output "microservice_2_service_account" {
  description = "Email of the microservice 2 service account"
  value       = google_service_account.microservice_2.email
}

output "cicd_service_account" {
  description = "Email of the CI/CD service account"
  value       = google_service_account.cicd.email
}

output "artifact_registry_repository" {
  description = "Name of the Artifact Registry repository"
  value       = google_artifact_registry_repository.main.name
}

output "artifact_registry_location" {
  description = "Location of the Artifact Registry repository"
  value       = google_artifact_registry_repository.main.location
}

output "docker_repository_url" {
  description = "URL of the Docker repository"
  value       = "${google_artifact_registry_repository.main.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.main.repository_id}"
}

# CI/CD Service Account Key (sensitive)
output "cicd_service_account_key" {
  description = "Base64 encoded private key for CI/CD service account"
  value       = google_service_account_key.cicd_key.private_key
  sensitive   = true
}

# Secret Manager secret names
output "microservice_1_secret_name" {
  description = "Name of the Secret Manager secret for microservice 1"
  value       = google_secret_manager_secret.microservice_1_sa.secret_id
}

output "microservice_2_secret_name" {
  description = "Name of the Secret Manager secret for microservice 2"
  value       = google_secret_manager_secret.microservice_2_sa.secret_id
}

# Service account keys (sensitive)
output "microservice_1_service_account_key" {
  description = "Base64 encoded private key for microservice 1 service account"
  value       = google_service_account_key.microservice_1_key.private_key
  sensitive   = true
}

output "microservice_2_service_account_key" {
  description = "Base64 encoded private key for microservice 2 service account"
  value       = google_service_account_key.microservice_2_key.private_key
  sensitive   = true
}