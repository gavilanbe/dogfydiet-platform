output "frontend_bucket_name" {
  description = "The name of the frontend storage bucket"
  value       = google_storage_bucket.frontend.name
}

output "frontend_bucket_url" {
  description = "The URL of the frontend storage bucket"
  value       = google_storage_bucket.frontend.url
}

output "frontend_bucket_self_link" {
  description = "The self-link of the frontend storage bucket"
  value       = google_storage_bucket.frontend.self_link
}

output "load_balancer_ip" {
  description = "The IP address of the load balancer"
  value       = google_compute_global_address.frontend.address
}

output "load_balancer_ip_name" {
  description = "The name of the load balancer IP address"
  value       = google_compute_global_address.frontend.name
}

output "frontend_url" {
  description = "The URL to access the frontend application"
  value       = "http://${google_compute_global_address.frontend.address}"
}

output "frontend_https_url" {
  description = "The HTTPS URL to access the frontend application"
  value       = var.enable_https ? "https://${google_compute_global_address.frontend.address}" : ""
}

output "custom_domain_url" {
  description = "The custom domain URL (if configured)"
  value       = var.custom_domain != "" ? (var.enable_https ? "https://${var.custom_domain}" : "http://${var.custom_domain}") : ""
}

output "backend_bucket_name" {
  description = "The name of the backend bucket"
  value       = google_compute_backend_bucket.frontend.name
}

output "url_map_name" {
  description = "The name of the URL map"
  value       = google_compute_url_map.frontend.name
}

output "ssl_certificate_name" {
  description = "The name of the SSL certificate (if HTTPS enabled)"
  value       = var.enable_https && var.custom_domain != "" ? google_compute_managed_ssl_certificate.frontend[0].name : ""
}