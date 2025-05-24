# Enable required APIs
resource "google_project_service" "monitoring" {
  service            = "monitoring.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "logging" {
  service            = "logging.googleapis.com"
  disable_on_destroy = false
}

# Notification channel for alerts
resource "google_monitoring_notification_channel" "email" {
  display_name = "${var.name_prefix} Email Notification Channel"
  type         = "email"
  
  labels = {
    email_address = var.notification_email
  }
  
  enabled = true
}

# Infrastructure Monitoring Alerts

# GKE Cluster CPU Usage Alert
resource "google_monitoring_alert_policy" "gke_cpu_usage" {
  display_name = "${var.name_prefix} GKE CPU Usage High"
  combiner     = "OR"
  enabled      = true
  
  documentation {
    content   = "Alert when GKE cluster CPU usage is consistently high"
    mime_type = "text/markdown"
  }
  
  conditions {
    display_name = "GKE CPU usage > 80%"
    
    condition_threshold {
      filter         = "resource.type=\"k8s_container\" AND resource.labels.cluster_name=\"${var.gke_cluster_name}\""
      duration       = "300s"
      comparison     = "COMPARISON_GREATER_THAN"
      threshold_value = 0.8
      
      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_MEAN"
        cross_series_reducer = "REDUCE_MEAN"
        group_by_fields      = ["resource.labels.cluster_name"]
      }
    }
  }
  
  notification_channels = [google_monitoring_notification_channel.email.name]
  
  alert_strategy {
    auto_close = "1800s"
  }
}

# GKE Cluster Memory Usage Alert
resource "google_monitoring_alert_policy" "gke_memory_usage" {
  display_name = "${var.name_prefix} GKE Memory Usage High"
  combiner     = "OR"
  enabled      = true
  
  documentation {
    content   = "Alert when GKE cluster memory usage is consistently high"
    mime_type = "text/markdown"
  }
  
  conditions {
    display_name = "GKE Memory usage > 85%"
    
    condition_threshold {
      filter         = "resource.type=\"k8s_container\" AND resource.labels.cluster_name=\"${var.gke_cluster_name}\""
      duration       = "300s"
      comparison     = "COMPARISON_GREATER_THAN"
      threshold_value = 0.85
      
      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_MEAN"
        cross_series_reducer = "REDUCE_MEAN"
        group_by_fields      = ["resource.labels.cluster_name"]
      }
    }
  }
  
  notification_channels = [google_monitoring_notification_channel.email.name]
  
  alert_strategy {
    auto_close = "1800s"
  }
}

# GKE Node Not Ready Alert
resource "google_monitoring_alert_policy" "gke_node_not_ready" {
  display_name = "${var.name_prefix} GKE Node Not Ready"
  combiner     = "OR"
  enabled      = true
  
  documentation {
    content   = "Alert when GKE nodes are not ready"
    mime_type = "text/markdown"
  }
  
  conditions {
    display_name = "GKE Node not ready"
    
    condition_threshold {
      filter         = "resource.type=\"k8s_node\" AND resource.labels.cluster_name=\"${var.gke_cluster_name}\""
      duration       = "300s"
      comparison     = "COMPARISON_LESS_THAN"
      threshold_value = 1
      
      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_MEAN"
        cross_series_reducer = "REDUCE_MIN"
        group_by_fields      = ["resource.labels.node_name"]
      }
    }
  }
  
  notification_channels = [google_monitoring_notification_channel.email.name]
  
  alert_strategy {
    auto_close = "1800s"
  }
}

# Application Monitoring Alerts

# HTTP Error Rate Alert
resource "google_monitoring_alert_policy" "http_error_rate" {
  display_name = "${var.name_prefix} HTTP Error Rate High"
  combiner     = "OR"
  enabled      = true
  
  documentation {
    content   = "Alert when HTTP error rate is high"
    mime_type = "text/markdown"
  }
  
  conditions {
    display_name = "HTTP 5xx error rate > 5%"
    
    condition_threshold {
      filter         = "resource.type=\"k8s_container\" AND metric.type=\"istio.io/service/server/request_count\""
      duration       = "300s"
      comparison     = "COMPARISON_GREATER_THAN"
      threshold_value = 0.05
      
      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["metric.labels.response_code"]
      }
    }
  }
  
  notification_channels = [google_monitoring_notification_channel.email.name]
  
  alert_strategy {
    auto_close = "1800s"
  }
}

# HTTP Latency Alert
resource "google_monitoring_alert_policy" "http_latency" {
  display_name = "${var.name_prefix} HTTP Latency High"
  combiner     = "OR"
  enabled      = true
  
  documentation {
    content   = "Alert when HTTP latency is consistently high"
    mime_type = "text/markdown"
  }
  
  conditions {
    display_name = "HTTP latency > 2s"
    
    condition_threshold {
      filter         = "resource.type=\"k8s_container\" AND metric.type=\"istio.io/service/server/response_latencies\""
      duration       = "300s"
      comparison     = "COMPARISON_GREATER_THAN"
      threshold_value = 2000  # 2 seconds in milliseconds
      
      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_DELTA"
        cross_series_reducer = "REDUCE_PERCENTILE_95"
      }
    }
  }
  
  notification_channels = [google_monitoring_notification_channel.email.name]
  
  alert_strategy {
    auto_close = "1800s"
  }
}

# Business Metrics Alerts

# Low Request Volume Alert
resource "google_monitoring_alert_policy" "low_request_volume" {
  display_name = "${var.name_prefix} Low Request Volume"
  combiner     = "OR"
  enabled      = true
  
  documentation {
    content   = "Alert when request volume is unusually low"
    mime_type = "text/markdown"
  }
  
  conditions {
    display_name = "Request volume < 10 requests/minute"
    
    condition_threshold {
      filter         = "resource.type=\"k8s_container\" AND metric.type=\"istio.io/service/server/request_count\""
      duration       = "600s"
      comparison     = "COMPARISON_LESS_THAN"
      threshold_value = 10
      
      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
      }
    }
  }
  
  notification_channels = [google_monitoring_notification_channel.email.name]
  
  alert_strategy {
    auto_close = "1800s"
  }
}

# Log-based Metrics

# Error Log Count Metric
resource "google_logging_metric" "error_count" {
  name   = "${var.name_prefix}_error_count"
  filter = "resource.type=\"k8s_container\" AND severity>=ERROR AND resource.labels.cluster_name=\"${var.gke_cluster_name}\""
  
  metric_descriptor {
    metric_kind = "COUNTER"
    value_type  = "INT64"
    display_name = "Error Log Count"
  }
  
  label_extractors = {
    "severity" = "EXTRACT(severity)"
    "service_name" = "EXTRACT(resource.labels.container_name)"
  }
}

# Log-based Alert for Errors
resource "google_monitoring_alert_policy" "error_logs" {
  display_name = "${var.name_prefix} High Error Log Count"
  combiner     = "OR"
  enabled      = true
  
  documentation {
    content   = "Alert when error log count is high"
    mime_type = "text/markdown"
  }
  
  conditions {
    display_name = "Error log count > 10/minute"
    
    condition_threshold {
      filter         = "metric.type=\"logging.googleapis.com/user/${google_logging_metric.error_count.name}\""
      duration       = "300s"
      comparison     = "COMPARISON_GREATER_THAN"
      threshold_value = 10
      
      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
      }
    }
  }
  
  notification_channels = [google_monitoring_notification_channel.email.name]
  
  alert_strategy {
    auto_close = "1800s"
  }
}

# Dashboard
resource "google_monitoring_dashboard" "main" {
  dashboard_json = jsonencode({
    displayName = "${var.name_prefix} Platform Dashboard"
    mosaicLayout = {
      tiles = [
        {
          width = 6
          height = 4
          widget = {
            title = "GKE CPU Usage"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"k8s_container\" AND resource.labels.cluster_name=\"${var.gke_cluster_name}\""
                      aggregation = {
                        alignmentPeriod = "300s"
                        perSeriesAligner = "ALIGN_MEAN"
                        crossSeriesReducer = "REDUCE_MEAN"
                        groupByFields = ["resource.labels.cluster_name"]
                      }
                    }
                  }
                  plotType = "LINE"
                }
              ]
              timeshiftDuration = "0s"
              yAxis = {
                label = "CPU Usage"
                scale = "LINEAR"
              }
            }
          }
        },
        {
          width = 6
          height = 4
          widget = {
            title = "Memory Usage"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"k8s_container\" AND resource.labels.cluster_name=\"${var.gke_cluster_name}\""
                      aggregation = {
                        alignmentPeriod = "300s"
                        perSeriesAligner = "ALIGN_MEAN"
                        crossSeriesReducer = "REDUCE_MEAN"
                        groupByFields = ["resource.labels.cluster_name"]
                      }
                    }
                  }
                  plotType = "LINE"
                }
              ]
              timeshiftDuration = "0s"
              yAxis = {
                label = "Memory Usage"
                scale = "LINEAR"
              }
            }
          }
        },
        {
          width = 12
          height = 4
          widget = {
            title = "Request Rate"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"k8s_container\" AND metric.type=\"istio.io/service/server/request_count\""
                      aggregation = {
                        alignmentPeriod = "300s"
                        perSeriesAligner = "ALIGN_RATE"
                        crossSeriesReducer = "REDUCE_SUM"
                      }
                    }
                  }
                  plotType = "LINE"
                }
              ]
              timeshiftDuration = "0s"
              yAxis = {
                label = "Requests/sec"
                scale = "LINEAR"
              }
            }
          }
        }
      ]
    }
  })
}