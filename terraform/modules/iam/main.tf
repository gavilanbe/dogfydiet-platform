# Service Account for Microservice 1 (Publisher)
resource "google_service_account" "microservice_1" {
  account_id   = "${var.name_prefix}-microservice-1"
  display_name = "Microservice 1 Service Account"
  description  = "Service account for microservice 1 in ${var.environment} environment"
}

# Service Account for Microservice 2 (Subscriber)
resource "google_service_account" "microservice_2" {
  account_id   = "${var.name_prefix}-microservice-2"
  display_name = "Microservice 2 Service Account"
  description  = "Service account for microservice 2 in ${var.environment} environment"
}

# Service Account for CI/CD
resource "google_service_account" "cicd" {
  account_id   = "${var.name_prefix}-cicd"
  display_name = "CI/CD Service Account"
  description  = "Service account for CI/CD pipeline in ${var.environment} environment"
}

# Workload Identity bindings for microservices
resource "google_service_account_iam_binding" "microservice_1_workload_identity" {
  service_account_id = google_service_account.microservice_1.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[${var.k8s_namespace}/microservice-1]"
  ]
}

resource "google_service_account_iam_binding" "microservice_2_workload_identity" {
  service_account_id = google_service_account.microservice_2.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[${var.k8s_namespace}/microservice-2]"
  ]
}

# Microservice 1 IAM permissions (Publisher role for Pub/Sub)
resource "google_project_iam_member" "microservice_1_pubsub_publisher" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.microservice_1.email}"
}

resource "google_project_iam_member" "microservice_1_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.microservice_1.email}"
}

resource "google_project_iam_member" "microservice_1_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.microservice_1.email}"
}

resource "google_project_iam_member" "microservice_1_trace" {
  project = var.project_id
  role    = "roles/cloudtrace.agent"
  member  = "serviceAccount:${google_service_account.microservice_1.email}"
}

# Microservice 2 IAM permissions (Subscriber role for Pub/Sub, Firestore access)
resource "google_project_iam_member" "microservice_2_pubsub_subscriber" {
  project = var.project_id
  role    = "roles/pubsub.subscriber"
  member  = "serviceAccount:${google_service_account.microservice_2.email}"
}

resource "google_project_iam_member" "microservice_2_firestore_user" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.microservice_2.email}"
}

resource "google_project_iam_member" "microservice_2_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.microservice_2.email}"
}

resource "google_project_iam_member" "microservice_2_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.microservice_2.email}"
}

resource "google_project_iam_member" "microservice_2_trace" {
  project = var.project_id
  role    = "roles/cloudtrace.agent"
  member  = "serviceAccount:${google_service_account.microservice_2.email}"
}

# CI/CD IAM permissions
resource "google_project_iam_member" "cicd_gke_developer" {
  project = var.project_id
  role    = "roles/container.developer"
  member  = "serviceAccount:${google_service_account.cicd.email}"
}

resource "google_project_iam_member" "cicd_artifact_registry_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.cicd.email}"
}

resource "google_project_iam_member" "cicd_storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.cicd.email}"
}

resource "google_project_iam_member" "cicd_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.cicd.email}"
}

# Create service account keys for CI/CD (not recommended for production)
resource "google_service_account_key" "cicd_key" {
  service_account_id = google_service_account.cicd.name
  public_key_type    = "TYPE_X509_PEM_FILE"
}

# Secret Manager secrets for service accounts
resource "google_secret_manager_secret" "microservice_1_sa" {
  secret_id = "${var.name_prefix}-microservice-1-sa"

  replication {
    auto {}
  }

  labels = var.labels
}

resource "google_secret_manager_secret_version" "microservice_1_sa" {
  secret      = google_secret_manager_secret.microservice_1_sa.id
  secret_data = base64decode(google_service_account_key.microservice_1_key.private_key)
}

resource "google_secret_manager_secret" "microservice_2_sa" {
  secret_id = "${var.name_prefix}-microservice-2-sa"

  replication {
    auto {}
  }

  labels = var.labels
}

resource "google_secret_manager_secret_version" "microservice_2_sa" {
  secret      = google_secret_manager_secret.microservice_2_sa.id
  secret_data = base64decode(google_service_account_key.microservice_2_key.private_key)
}

# Service account keys for microservices (for local development)
resource "google_service_account_key" "microservice_1_key" {
  service_account_id = google_service_account.microservice_1.name
  public_key_type    = "TYPE_X509_PEM_FILE"
}

resource "google_service_account_key" "microservice_2_key" {
  service_account_id = google_service_account.microservice_2.name
  public_key_type    = "TYPE_X509_PEM_FILE"
}

# Custom IAM roles for fine-grained permissions
resource "google_project_iam_custom_role" "microservice_minimal" {
  role_id     = "${var.name_prefix}_microservice_minimal"
  title       = "Microservice Minimal Permissions"
  description = "Minimal permissions required for microservices"

  permissions = [
    "logging.logEntries.create",
    "monitoring.timeSeries.create",
    "cloudtrace.traces.patch"
  ]

  stage = "GA"
}

# Bind custom role to service accounts
resource "google_project_iam_member" "microservice_1_custom" {
  project = var.project_id
  role    = google_project_iam_custom_role.microservice_minimal.id
  member  = "serviceAccount:${google_service_account.microservice_1.email}"
}

resource "google_project_iam_member" "microservice_2_custom" {
  project = var.project_id
  role    = google_project_iam_custom_role.microservice_minimal.id
  member  = "serviceAccount:${google_service_account.microservice_2.email}"
}

# Enable required APIs
resource "google_project_service" "iam" {
  service            = "iam.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "secretmanager" {
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "artifactregistry" {
  service            = "artifactregistry.googleapis.com"
  disable_on_destroy = false
}

# Artifact Registry repository for Docker images
resource "google_artifact_registry_repository" "main" {
  location      = var.region
  repository_id = "${var.name_prefix}-docker-repo"
  description   = "Docker repository for ${var.environment} environment"
  format        = "DOCKER"

  labels = var.labels

  depends_on = [google_project_service.artifactregistry]
}