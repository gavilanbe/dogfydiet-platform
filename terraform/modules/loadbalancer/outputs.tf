output "load_balancer_ip" {
  description = "The IP address of the load balancer"
  value       = google_compute_global_address.main.address
}

output "load_balancer_ip_name" {
  description = "The name of the load balancer IP address resource"
  value       = google_compute_global_address.main.name
}

output "load_balancer_ip_self_link" {
  description = "The self-link of the load balancer IP address"
  value       = google_compute_global_address.main.self_link
}

output "url_map_id" {
  description = "The ID of the URL map"
  value       = google_compute_url_map.main.id
}

output "url_map_self_link" {
  description = "The self-link of the URL map"
  value       = google_compute_url_map.main.self_link
}

output "http_proxy_id" {
  description = "The ID of the HTTP proxy"
  value       = google_compute_target_http_proxy.main.id
}

output "https_proxy_id" {
  description = "The ID of the HTTPS proxy (if enabled)"
  value       = var.enable_https ? google_compute_target_https_proxy.main[0].id : null
}

output "http_forwarding_rule_id" {
  description = "The ID of the HTTP forwarding rule"
  value       = google_compute_global_forwarding_rule.http.id
}

output "https_forwarding_rule_id" {
  description = "The ID of the HTTPS forwarding rule (if enabled)"
  value       = var.enable_https ? google_compute_global_forwarding_rule.https[0].id : null
}

output "ssl_certificate_id" {
  description = "The ID of the managed SSL certificate (if created)"
  value       = var.enable_https && var.create_managed_certificate ? google_compute_managed_ssl_certificate.main[0].id : null
}

output "ssl_certificate_self_link" {
  description = "The self-link of the managed SSL certificate (if created)"
  value       = var.enable_https && var.create_managed_certificate ? google_compute_managed_ssl_certificate.main[0].self_link : null
}

output "ssl_policy_id" {
  description = "The ID of the SSL policy (if created)"
  value       = var.enable_https && var.create_ssl_policy ? google_compute_ssl_policy.main[0].id : null
}

output "cloud_armor_policy_id" {
  description = "The ID of the Cloud Armor security policy (if enabled)"
  value       = var.enable_cloud_armor ? google_compute_security_policy.main[0].id : null
}

output "backend_service_id" {
  description = "The ID of the backend service (if created)"
  value       = var.create_backend_service ? google_compute_backend_service.main[0].id : null
}

output "load_balancer_url" {
  description = "The URL to access the load balancer"
  value       = "http://${google_compute_global_address.main.address}"
}

output "load_balancer_https_url" {
  description = "The HTTPS URL to access the load balancer (if enabled)"
  value       = var.enable_https ? "https://${google_compute_global_address.main.address}" : null
}