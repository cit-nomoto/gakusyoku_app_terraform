# setup.sh / deploy.sh から参照する値

output "project_id" {
  value = var.project_id
}

output "region" {
  value = var.region
}

output "app_name" {
  value = var.app_name
}

# グループごとの Cloud Run URL
output "urls" {
  value = { for name, m in module.group : name => m.url }
}

# グループごとのソースアップロード先バケット
output "source_buckets" {
  value = { for name, m in module.group : name => m.source_bucket }
}
