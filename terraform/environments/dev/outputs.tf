# Network Outputs
output "vpc_network_name" {
  description = "The name of the VPC network"
  value       = module.vpc.network_name
}

output "vpc_network_self_link" {
  description = "The self-link of the VPC network"
  value       = module.vpc.network_self_link
}

output "private_subnet_name" {
  description = "The name of the private subnet"
  value       = module.vpc.private_subnet_name  
}

output "public_subnet_name" {
  description = "The name of the public subnet"
  value       = module.vpc.public_subnet_name
}

# GKE Outputs
output "gke_cluster_name" {
  description = "The name of the GKE cluster"
  value       = module.gke.cluster_name
}

output "gke_cluster_endpoint" {
  description = "The endpoint of the GKE cluster"
  value       = module.gke.endpoint
  sensitive   = true
}

output "gke_cluster_ca_certificate" {
  description = "The CA certificate of the GKE cluster"
  value       = module.gke.ca_certificate
  sensitive   = true
}

output "gke_cluster_location" {
  description = "The location of the GKE cluster"
  value       = module.gke.location
}

# Storage Outputs
output "frontend_bucket_name" {
  description = "The name of the frontend storage bucket"
  value       = module.storage.frontend_bucket_name
}

output "frontend_bucket_url" {
  description = "The URL of the frontend storage bucket"
  value       = module.storage.frontend_bucket_url
}

# Pub/Sub Outputs
output "pubsub_topic_name" {
  description = "The name of the Pub/Sub topic"
  value       = module.pubsub.topic_name
}

output "pubsub_subscription_name" {
  description = "The name of the Pub/Sub subscription"
  value       = module.pubsub.subscription_name
}

# Firestore Outputs
output "firestore_database_name" {
  description = "The name of the Firestore database"
  value       = module.firestore.database_name
}

# IAM Outputs
output "microservice_1_service_account" {
  description = "Service account email for microservice 1"
  value       = module.iam.microservice_1_service_account
}

output "microservice_2_service_account" {
  description = "Service account email for microservice 2"
  value       = module.iam.microservice_2_service_account
}

# Monitoring Outputs
output "monitoring_notification_channel" {
  description = "Monitoring notification channel ID"
  value       = module.monitoring.notification_channel_id
}