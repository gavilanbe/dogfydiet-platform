output "cluster_name" {
  description = "The name of the GKE cluster"
  value       = google_container_cluster.primary.name
}

output "cluster_id" {
  description = "The ID of the GKE cluster"
  value       = google_container_cluster.primary.id
}

output "endpoint" {
  description = "The endpoint of the GKE cluster"
  value       = google_container_cluster.primary.endpoint
  sensitive   = true
}

output "ca_certificate" {
  description = "The CA certificate of the GKE cluster"
  value       = google_container_cluster.primary.master_auth.0.cluster_ca_certificate
  sensitive   = true
}

output "location" {
  description = "The location of the GKE cluster"
  value       = google_container_cluster.primary.location
}

output "master_version" {
  description = "The current master version of the GKE cluster"
  value       = google_container_cluster.primary.master_version
}

output "node_version" {
  description = "The current node version of the GKE cluster"
  value       = google_container_cluster.primary.node_version
}

output "node_pool_name" {
  description = "The name of the primary node pool"
  value       = google_container_node_pool.primary.name
}

output "node_service_account" {
  description = "The service account used by GKE nodes"
  value       = google_service_account.gke_nodes.email
}

output "cluster_resource_labels" {
  description = "The resource labels applied to the cluster"
  value       = google_container_cluster.primary.resource_labels
}

# Connection information for kubectl
output "kubectl_config" {
  description = "kubectl configuration command"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --region ${google_container_cluster.primary.location} --project ${var.project_id}"
}