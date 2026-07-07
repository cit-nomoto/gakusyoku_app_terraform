# --- アプリ実行用サービスアカウント（グループ専用） ---

resource "google_service_account" "app" {
  account_id   = local.name
  display_name = "${local.name} runtime SA"
}

# Litestream が自グループの DB バケットへ読み書きするための権限
# プロジェクト全体ではなくバケット単位で付与し、他グループの DB に触れないようにする
resource "google_storage_bucket_iam_member" "app_db_object_admin" {
  bucket = google_storage_bucket.db.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.app.email}"
}

# --- Cloud Run サービス ---

resource "google_cloud_run_v2_service" "main" {
  name     = local.service_name
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = google_service_account.app.email

    scaling {
      min_instance_count = 0
      max_instance_count = 1
    }

    containers {
      # 初回 apply 時はアプリイメージがまだ存在しないためプレースホルダで作成する。
      # source.zip のアップロードを検知した Cloud Build が実イメージをデプロイする。
      image = "us-docker.pkg.dev/cloudrun/container/hello"

      ports {
        container_port = 8080
      }

      # litestream.yml が参照するレプリカ先バケット名
      env {
        name  = "REPLICA_BUCKET"
        value = google_storage_bucket.db.name
      }
    }
  }

  # イメージは Cloud Build（gcloud run deploy）側で更新されるため Terraform では追跡しない
  lifecycle {
    ignore_changes = [template[0].containers[0].image]
  }
}

# 公開アクセス（IAM 認証なし）
resource "google_cloud_run_v2_service_iam_member" "cloud_run_noauth" {
  location = google_cloud_run_v2_service.main.location
  project  = google_cloud_run_v2_service.main.project
  name     = google_cloud_run_v2_service.main.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
