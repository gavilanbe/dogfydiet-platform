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
      filter          = "resource.type=\"k8s_container\" AND resource.labels.cluster_name=\"${var.gke_cluster_name}\" AND metric.type=\"kubernetes.io/container/cpu/core_usage_time\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.8

      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_MEAN"
        group_by_fields      = ["resource.labels.namespace_name", "resource.labels.pod_name"]
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
      filter          = "resource.type=\"k8s_container\" AND resource.labels.cluster_name=\"${var.gke_cluster_name}\" AND metric.type=\"kubernetes.io/container/memory/used_bytes\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 435159040 # ~415MB (85% of 512MB)

      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_MEAN"
        cross_series_reducer = "REDUCE_MEAN"
        group_by_fields      = ["resource.labels.namespace_name", "resource.labels.pod_name"]
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.name]

  alert_strategy {
    auto_close = "1800s"
  }
}

# GKE Pod Restart Alert
resource "google_monitoring_alert_policy" "gke_pod_restarts" {
  display_name = "${var.name_prefix} GKE Pod Restart Alert"
  combiner     = "OR"
  enabled      = true

  documentation {
    content   = "Alert when GKE pods are restarting frequently"
    mime_type = "text/markdown"
  }

  conditions {
    display_name = "Pod restart rate is high"

    condition_threshold {
      filter          = "resource.type=\"k8s_pod\" AND resource.labels.cluster_name=\"${var.gke_cluster_name}\" AND metric.type=\"kubernetes.io/pod/restart_count\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 5

      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["resource.labels.pod_name"]
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.name]

  alert_strategy {
    auto_close = "1800s"
  }
}

# Application Monitoring Alerts

# HTTP Error Rate Alert (placeholder - will work when service mesh is enabled)
resource "google_monitoring_alert_policy" "http_error_rate" {
  display_name = "${var.name_prefix} HTTP Error Rate High"
  combiner     = "OR"
  enabled      = false # Disabled until service mesh metrics are available

  documentation {
    content   = "Alert when HTTP error rate is high (requires service mesh)"
    mime_type = "text/markdown"
  }

  conditions {
    display_name = "HTTP 5xx error rate > 5%"

    condition_threshold {
      filter          = "resource.type=\"k8s_container\" AND metric.type=\"kubernetes.io/container/cpu/core_usage_time\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.05

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

# HTTP Latency Alert (placeholder - will work when service mesh is enabled)
resource "google_monitoring_alert_policy" "http_latency" {
  display_name = "${var.name_prefix} HTTP Latency High"
  combiner     = "OR"
  enabled      = false # Disabled until service mesh metrics are available

  documentation {
    content   = "Alert when HTTP latency is consistently high (requires service mesh)"
    mime_type = "text/markdown"
  }

  conditions {
    display_name = "HTTP latency > 2s"

    condition_threshold {
      filter          = "resource.type=\"k8s_container\" AND metric.type=\"kubernetes.io/container/cpu/core_usage_time\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 2000

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

# Business Metrics Alert - Low Pod Count
resource "google_monitoring_alert_policy" "low_pod_count" {
  display_name = "${var.name_prefix} Low Pod Count"
  combiner     = "OR"
  enabled      = true

  documentation {
    content   = "Alert when pod count is too low"
    mime_type = "text/markdown"
  }

  conditions {
    display_name = "Pod count < 2"

    condition_threshold {
      filter          = "resource.type=\"k8s_pod\" AND resource.labels.cluster_name=\"${var.gke_cluster_name}\" AND metric.type=\"kubernetes.io/pod/uptime\""
      duration        = "300s"
      comparison      = "COMPARISON_LT"
      threshold_value = 2

      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_MEAN"
        cross_series_reducer = "REDUCE_COUNT"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.name]

  alert_strategy {
    auto_close = "1800s"
  }
}

# Error Log Count Metric
resource "google_logging_metric" "error_count" {
  name   = "${var.name_prefix}_error_count"
  filter = "resource.type=\"k8s_container\" AND severity>=ERROR AND resource.labels.cluster_name=\"${var.gke_cluster_name}\""

  metric_descriptor {
    metric_kind  = "DELTA"
    value_type   = "INT64"
    display_name = "Error Log Count"

    labels {
      key         = "severity"
      value_type  = "STRING"
      description = "Severity of the log entry"
    }

    labels {
      key         = "service_name"
      value_type  = "STRING"
      description = "Name of the service"
    }
  }

  label_extractors = {
    "severity"     = "EXTRACT(severity)"
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
      filter          = "metric.type=\"logging.googleapis.com/user/${google_logging_metric.error_count.name}\" AND resource.type=\"k8s_container\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
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
      columns = 12
      tiles = [
        {
          width  = 6
          height = 4
          widget = {
            title = "GKE CPU Usage"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"k8s_container\" AND metric.type=\"kubernetes.io/container/cpu/core_usage_time\" AND resource.labels.cluster_name=\"${var.gke_cluster_name}\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_RATE"
                        crossSeriesReducer = "REDUCE_MEAN"
                        groupByFields      = ["resource.labels.namespace_name"]
                      }
                    }
                  }
                  plotType   = "LINE"
                  targetAxis = "Y1"
                }
              ]
              timeshiftDuration = "0s"
              yAxis = {
                label = "CPU cores"
                scale = "LINEAR"
              }
            }
          }
        },
        {
          xPos   = 6
          width  = 6
          height = 4
          widget = {
            title = "Memory Usage"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"k8s_container\" AND metric.type=\"kubernetes.io/container/memory/used_bytes\" AND resource.labels.cluster_name=\"${var.gke_cluster_name}\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_MEAN"
                        crossSeriesReducer = "REDUCE_MEAN"
                        groupByFields      = ["resource.labels.namespace_name"]
                      }
                    }
                  }
                  plotType   = "LINE"
                  targetAxis = "Y1"
                }
              ]
              timeshiftDuration = "0s"
              yAxis = {
                label = "Memory (bytes)"
                scale = "LINEAR"
              }
            }
          }
        },
        {
          yPos   = 4
          width  = 12
          height = 4
          widget = {
            title = "Pod Restart Count"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"k8s_pod\" AND metric.type=\"kubernetes.io/pod/restart_count\" AND resource.labels.cluster_name=\"${var.gke_cluster_name}\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_RATE"
                        crossSeriesReducer = "REDUCE_SUM"
                        groupByFields      = ["resource.labels.pod_name"]
                      }
                    }
                  }
                  plotType   = "LINE"
                  targetAxis = "Y1"
                }
              ]
              timeshiftDuration = "0s"
              yAxis = {
                label = "Restarts/sec"
                scale = "LINEAR"
              }
            }
          }
        },
        {
          yPos   = 8
          width  = 6
          height = 4
          widget = {
            title = "Error Log Rate"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "metric.type=\"logging.googleapis.com/user/${google_logging_metric.error_count.name}\" AND resource.type=\"k8s_container\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_RATE"
                        crossSeriesReducer = "REDUCE_SUM"
                        groupByFields      = ["metric.labels.service_name"]
                      }
                    }
                  }
                  plotType   = "LINE"
                  targetAxis = "Y1"
                }
              ]
              timeshiftDuration = "0s"
              yAxis = {
                label = "Errors/sec"
                scale = "LINEAR"
              }
            }
          }
        },
        {
          xPos   = 6
          yPos   = 8
          width  = 6
          height = 4
          widget = {
            title = "Pod Count"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"k8s_pod\" AND metric.type=\"kubernetes.io/pod/uptime\" AND resource.labels.cluster_name=\"${var.gke_cluster_name}\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_MEAN"
                        crossSeriesReducer = "REDUCE_COUNT"
                        groupByFields      = ["resource.labels.namespace_name"]
                      }
                    }
                  }
                  plotType   = "LINE"
                  targetAxis = "Y1"
                }
              ]
              timeshiftDuration = "0s"
              yAxis = {
                label = "Pod Count"
                scale = "LINEAR"
              }
            }
          }
        }
      ]
    }
  })
}