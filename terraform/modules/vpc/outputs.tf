# terraform/modules/vpc/outputs.tf

output "network_name" {
  description = "The name of the VPC network"
  value       = google_compute_network.main.name
}

output "network_self_link" {
  description = "The self-link of the VPC network"
  value       = google_compute_network.main.self_link
}

output "network_id" {
  description = "The ID of the VPC network"
  value       = google_compute_network.main.id
}

output "private_subnet_name" {
  description = "The name of the private subnet"
  value       = google_compute_subnetwork.private.name
}

output "private_subnet_self_link" {
  description = "The self-link of the private subnet"
  value       = google_compute_subnetwork.private.self_link
}

output "private_subnet_cidr" {
  description = "The CIDR block of the private subnet"
  value       = google_compute_subnetwork.private.ip_cidr_range
}

output "public_subnet_name" {
  description = "The name of the public subnet"
  value       = google_compute_subnetwork.public.name
}

output "public_subnet_self_link" {
  description = "The self-link of the public subnet"
  value       = google_compute_subnetwork.public.self_link
}

output "public_subnet_cidr" {
  description = "The CIDR block of the public subnet"
  value       = google_compute_subnetwork.public.ip_cidr_range
}

output "pods_cidr_range" {
  description = "The CIDR range for GKE pods"
  value       = var.pods_cidr_range
}

output "services_cidr_range" {
  description = "The CIDR range for GKE services"
  value       = var.services_cidr_range
}

output "gke_master_cidr" {
  description = "The CIDR range for GKE master nodes"
  value       = var.gke_master_cidr
}

output "router_name" {
  description = "The name of the Cloud Router"
  value       = google_compute_router.main.name
}

output "nat_name" {
  description = "The name of the NAT gateway"
  value       = google_compute_router_nat.main.name
}