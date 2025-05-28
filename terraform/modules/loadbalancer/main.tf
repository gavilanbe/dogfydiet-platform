resource "google_compute_global_address" "main" {
  name         = "${var.name_prefix}-lb-ip"
  description  = "Static IP address for load balancer"
  address_type = "EXTERNAL"
  ip_version   = "IPV4"

  labels = var.labels
}

# --- START: Health Check for GKE Backend (microservice-1) ---
resource "google_compute_health_check" "gke_ms1_health_check" {
  count = var.enable_gke_backend ? 1 : 0

  name                = "${var.name_prefix}-ms1-hc"
  description         = "Health check for Microservice 1"
  check_interval_sec  = 15 # From your backendconfig.yaml
  timeout_sec         = 5  # From your backendconfig.yaml
  healthy_threshold   = 2  # From your backendconfig.yaml
  unhealthy_threshold = 2  # From your backendconfig.yaml

  http_health_check {
    port_specification = "USE_SERVING_PORT" # NEG will provide the port
    request_path       = var.gke_health_check_request_path
  }
}
# --- END: Health Check for GKE Backend (microservice-1) ---

# --- START: Backend Service for GKE NEG (microservice-1) ---
data "google_compute_network_endpoint_group" "gke_ms1_neg" {
  count = var.enable_gke_backend ? 1 : 0

  name    = var.gke_neg_name
  zone    = var.gke_neg_zone # Make sure this is the zone of your GKE cluster/nodes
  project = var.project_id
}

resource "google_compute_backend_service" "gke_ms1_backend" {
  count = var.enable_gke_backend ? 1 : 0

  name                  = "${var.name_prefix}-ms1-backend"
  description           = "Backend service for Microservice 1 (GKE NEG)"
  protocol              = "HTTP"                            # Assuming microservice-1 serves HTTP
  port_name             = var.gke_backend_service_port_name # Should match the service port name in k8s service for ms1
  timeout_sec           = 30
  load_balancing_scheme = "EXTERNAL_MANAGED" # For Global HTTP(S) LB with NEGs
  enable_cdn            = false              # Usually not needed for API backends

  backend {
    group                 = data.google_compute_network_endpoint_group.gke_ms1_neg[0].self_link
    balancing_mode        = "RATE" # Good for HTTP services
    max_rate_per_endpoint = 100    # Adjust as needed
  }

  health_checks = [google_compute_health_check.gke_ms1_health_check[0].self_link]

  log_config {
    enable      = var.enable_logging
    sample_rate = var.log_sample_rate
  }

  # If you have a BackendConfig for this service in k8s, its settings (like IAP, CDN)
  # are applied by GKE. For Terraform managed backend services with NEGs,
  # you often configure these directly here or leave them to GKE if using `BackendConfig`
  # with the service.
  # If using BackendConfig for IAP, timeout, etc. from GKE, ensure it's correctly associated
  # with the K8s service. For health checks, it's safer to also define it in TF for the backend_service.

  # security_policy = var.enable_cloud_armor ? google_compute_security_policy.main[0].id : null
  # dynamic "iap" {
  #   for_each = var.iap_oauth2_client_id != "" ? [1] : []
  #   content {
  #     oauth2_client_id     = var.iap_oauth2_client_id
  #     oauth2_client_secret = var.iap_oauth2_client_secret
  #   }
  # }
}
# --- END: Backend Service for GKE NEG (microservice-1) ---
resource "google_compute_url_map" "main" {
  name            = "${var.name_prefix}-lb-urlmap"
  description     = "URL map for load balancer"
  default_service = var.default_backend_service // Default for the URL Map if no host rule matches

  dynamic "host_rule" {
    for_each = var.host_rules // This will be populated by the change in environments/dev/main.tf
    content {
      hosts        = host_rule.value.hosts
      path_matcher = host_rule.value.path_matcher // This should be "path-matcher-1"
    }
  }

  // This path_matcher is referenced by the host_rule.
  // Its name needs to be "path-matcher-1".
  // Its default_service will handle "/*" for "nahueldog.duckdns.org".
  // Its dynamic path_rule will handle "/api/*" for "nahueldog.duckdns.org".
  path_matcher {
    name            = "path-matcher-1"            // MODIFIED: Changed from "allpaths"
    default_service = var.default_backend_service // This is module.storage.backend_bucket_self_link via variable

    // Path rule for the GKE API backend
    dynamic "path_rule" {
      for_each = var.enable_gke_backend ? [1] : [] // Ensure var.enable_gke_backend is true
      content {
        paths   = ["/api/*"]
        service = google_compute_backend_service.gke_ms1_backend[0].self_link
      }
    }

    // REMOVED the static path_rule for paths = ["/*"].
    // The default_service of this path_matcher ("path-matcher-1") will handle requests
    // to "nahueldog.duckdns.org/*" that don't match the "/api/*" path_rule.
  }
}

# HTTP(S) Load Balancer - HTTPS proxy
resource "google_compute_target_https_proxy" "main" {
  count = var.enable_https ? 1 : 0

  name             = "${var.name_prefix}-lb-https-proxy"
  description      = "HTTPS proxy for load balancer"
  url_map          = google_compute_url_map.main.id
  ssl_certificates = var.ssl_certificates
  ssl_policy       = var.ssl_policy

  quic_override = var.enable_quic ? "ENABLE" : "DISABLE"
}

# For HTTP to HTTPS redirect
resource "google_compute_target_http_proxy" "main" {
  name        = "${var.name_prefix}-lb-http-proxy"
  description = "HTTP proxy for load balancer"
  url_map     = var.enable_https && var.https_redirect ? google_compute_url_map.redirect[0].id : google_compute_url_map.main.id
}

# URL map for HTTP to HTTPS redirect
resource "google_compute_url_map" "redirect" {
  count = var.enable_https && var.https_redirect ? 1 : 0

  name        = "${var.name_prefix}-lb-redirect-urlmap"
  description = "URL map for HTTP to HTTPS redirect"

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

resource "google_compute_global_forwarding_rule" "https" {
  count = var.enable_https ? 1 : 0

  name                  = "${var.name_prefix}-lb-https-forwarding-rule"
  description           = "HTTPS forwarding rule for load balancer"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "443"
  target                = google_compute_target_https_proxy.main[0].id
  ip_address            = google_compute_global_address.main.id

  labels = var.labels
}

resource "google_compute_global_forwarding_rule" "http" {
  name                  = "${var.name_prefix}-lb-http-forwarding-rule"
  description           = "HTTP forwarding rule for load balancer"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_target_http_proxy.main.id
  ip_address            = google_compute_global_address.main.id

  labels = var.labels
}

# SSL Certificate (managed by Google)
resource "google_compute_managed_ssl_certificate" "main" {
  count = var.enable_https && var.create_managed_certificate ? 1 : 0

  name        = "${var.name_prefix}-lb-ssl-cert"
  description = "Managed SSL certificate for load balancer"

  managed {
    domains = var.managed_certificate_domains
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_ssl_policy" "main" {
  count = var.enable_https && var.create_ssl_policy ? 1 : 0

  name            = "${var.name_prefix}-lb-ssl-policy"
  description     = "SSL policy for load balancer"
  profile         = var.ssl_policy_profile
  min_tls_version = var.ssl_policy_min_tls_version
}

resource "google_compute_security_policy" "main" {
  count = var.enable_cloud_armor ? 1 : 0

  name        = "${var.name_prefix}-lb-security-policy"
  description = "Cloud Armor security policy for load balancer"

  rule {
    action   = "allow"
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default rule"
  }

  dynamic "rule" {
    for_each = var.enable_rate_limiting ? [1] : []
    content {
      action   = "rate_based_ban"
      priority = "1000"
      match {
        versioned_expr = "SRC_IPS_V1"
        config {
          src_ip_ranges = ["*"]
        }
      }
      rate_limit_options {
        conform_action = "allow"
        exceed_action  = "deny(429)"
        rate_limit_threshold {
          count        = var.rate_limit_threshold
          interval_sec = var.rate_limit_interval
        }
        ban_duration_sec = var.rate_limit_ban_duration
      }
      description = "Rate limiting rule"
    }
  }

  dynamic "rule" {
    for_each = var.cloud_armor_rules
    content {
      action   = rule.value.action
      priority = rule.value.priority
      match {
        versioned_expr = rule.value.versioned_expr
        config {
          src_ip_ranges = rule.value.src_ip_ranges
        }
      }
      description = rule.value.description
    }
  }
}

# resource "google_compute_backend_service" "main" {
#   count = var.create_backend_service ? 1 : 0

#   name        = "${var.name_prefix}-lb-backend-service"
#   description = "Backend service for load balancer"

#   protocol    = var.backend_protocol
#   port_name   = var.backend_port_name
#   timeout_sec = var.backend_timeout

#   health_checks = var.health_checks

#   security_policy = var.enable_cloud_armor ? google_compute_security_policy.main[0].id : null

#   log_config {
#     enable      = var.enable_logging
#     sample_rate = var.log_sample_rate
#   }

#   iap {
#     oauth2_client_id     = var.iap_oauth2_client_id
#     oauth2_client_secret = var.iap_oauth2_client_secret
#   }
# }