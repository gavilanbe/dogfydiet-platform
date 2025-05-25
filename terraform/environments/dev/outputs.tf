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

# Load Balancer Outputs
output "load_balancer_ip" {
  description = "The static IP address of the load balancer"
  value       = module.loadbalancer.load_balancer_ip
}

output "load_balancer_url" {
  description = "The URL to access the application via load balancer"
  value       = module.loadbalancer.load_balancer_url
}

output "frontend_url" {
  description = "The URL to access the frontend application"
  value       = "http://${module.loadbalancer.load_balancer_ip}"
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

output "docker_repository_url" {
  description = "URL of the Docker repository"
  value       = module.iam.docker_repository_url
}

# Monitoring Outputs
output "monitoring_notification_channel" {
  description = "Monitoring notification channel ID"
  value       = module.monitoring.notification_channel_id
}

# kubectl configuration command
output "kubectl_config" {
  description = "Command to configure kubectl"
  value       = module.gke.kubectl_config
}

# Important URLs and commands
output "setup_instructions" {
  description = "Post-deployment setup instructions"
  value       = <<-EOT
    
    ========================================
    🚀 DogfyDiet Platform Deployment Complete!
    ========================================
    
    Frontend URL: http://${module.loadbalancer.load_balancer_ip}
    Frontend Bucket: ${module.storage.frontend_bucket_name}
    
    To configure kubectl:
    ${module.gke.kubectl_config}
    
    To deploy applications:
    1. Update GitHub secret FRONTEND_BUCKET_NAME with: ${module.storage.frontend_bucket_name}
    2. Update GitHub secret API_URL with: http://${module.loadbalancer.load_balancer_ip}/api
    3. Push changes to trigger CI/CD pipeline
    
    To access the frontend directly via bucket:
    ${module.storage.frontend_bucket_website_url}
    
  EOT
}