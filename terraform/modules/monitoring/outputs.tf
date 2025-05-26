output "notification_channel_id" {
  description = "ID of the email notification channel"
  value       = google_monitoring_notification_channel.email.name
}

output "notification_channel_name" {
  description = "Name of the email notification channel"
  value       = google_monitoring_notification_channel.email.display_name
}

output "dashboard_url" {
  description = "URL to access the monitoring dashboard"
  value       = "https://console.cloud.google.com/monitoring/dashboards/custom/${basename(google_monitoring_dashboard.main.id)}?project=${var.project_id}"
}

# output "alert_policies" {
#   description = "List of created alert policy names"
#   value = [
#     google_monitoring_alert_policy.gke_cpu_usage.display_name,
#     google_monitoring_alert_policy.gke_memory_usage.display_name,
#     google_monitoring_alert_policy.gke_node_not_ready.display_name,
#     google_monitoring_alert_policy.http_error_rate.display_name,
#     google_monitoring_alert_policy.http_latency.display_name,
#     google_monitoring_alert_policy.low_request_volume.display_name,
#     google_monitoring_alert_policy.error_logs.display_name
#   ]
# }

output "log_metric_name" {
  description = "Name of the error count log metric"
  value       = google_logging_metric.error_count.name
}

output "dashboard_id" {
  description = "ID of the monitoring dashboard"
  value       = google_monitoring_dashboard.main.id
}