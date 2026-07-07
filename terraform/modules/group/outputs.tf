output "url" {
  description = "Cloud Run サービスの URL"
  value       = google_cloud_run_v2_service.main.uri
}

output "source_bucket" {
  description = "オペレータがソースをアップロードするバケット名"
  value       = google_storage_bucket.source.name
}

output "service_name" {
  description = "Cloud Run サービス名"
  value       = google_cloud_run_v2_service.main.name
}
