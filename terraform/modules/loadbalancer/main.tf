resource "google_compute_global_address" "main" {
  name         = "${var.name_prefix}-lb-ip"
  description  = "Static IP address for load balancer"
  address_type = "EXTERNAL"
  ip_version   = "IPV4"
  
  labels = var.labels
}

resource "google_compute_url_map" "main" {
  name            = "${var.name_prefix}-lb-urlmap"
  description     = "URL map for load balancer"
  default_service = var.default_backend_service
  
  dynamic "host_rule" {
    for_each = var.host_rules
    content {
      hosts        = host_rule.value.hosts
      path_matcher = host_rule.value.path_matcher
    }
  }
  
  dynamic "path_matcher" {
    for_each = var.path_matchers
    content {
      name            = path_matcher.value.name
      default_service = path_matcher.value.default_service
      
      dynamic "path_rule" {
        for_each = path_matcher.value.path_rules
        content {
          paths   = path_rule.value.paths
          service = path_rule.value.service
        }
      }
    }
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

resource "google_compute_backend_service" "main" {
  count = var.create_backend_service ? 1 : 0
  
  name        = "${var.name_prefix}-lb-backend-service"
  description = "Backend service for load balancer"
  
  protocol    = var.backend_protocol
  port_name   = var.backend_port_name
  timeout_sec = var.backend_timeout
  
  health_checks = var.health_checks
  
  security_policy = var.enable_cloud_armor ? google_compute_security_policy.main[0].id : null
  
  log_config {
    enable      = var.enable_logging
    sample_rate = var.log_sample_rate
  }
  
  iap {
    oauth2_client_id     = var.iap_oauth2_client_id
    oauth2_client_secret = var.iap_oauth2_client_secret
  }
}