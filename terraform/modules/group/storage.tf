# --- Litestream レプリカ用バケット（グループ専用） ---
# バケット名は Cloud Run の環境変数 REPLICA_BUCKET 経由で litestream.yml に渡される

resource "google_storage_bucket" "db" {
  name          = "${var.project_id}-${var.group_name}-db"
  location      = var.region
  force_destroy = true
}

# --- ソースアップロード用バケット（グループ専用） ---
# グループごとにバケットを分けることで、オペレータが他グループの
# ソースを閲覧・上書きできないようにする

resource "google_storage_bucket" "source" {
  name                        = "${var.project_id}-${var.group_name}-source"
  location                    = var.region
  force_destroy               = true
  uniform_bucket_level_access = true
}

# Terraform 実行ユーザーにバケットの管理権限を付与
resource "google_storage_bucket_iam_member" "terraform_runner_admin" {
  bucket = google_storage_bucket.source.name
  role   = "roles/storage.admin"
  member = "user:${var.terraform_runner_email}"
}

# Docker ビルド用ファイルを Terraform で管理・アップロード
resource "google_storage_bucket_object" "dockerfile" {
  name   = "config/Dockerfile"
  bucket = google_storage_bucket.source.name
  source = "${path.module}/../../../docker/Dockerfile"
}

resource "google_storage_bucket_object" "litestream_yml" {
  name   = "config/litestream.yml"
  bucket = google_storage_bucket.source.name
  source = "${path.module}/../../../docker/litestream.yml"
}

resource "google_storage_bucket_object" "run_sh" {
  name   = "config/run.sh"
  bucket = google_storage_bucket.source.name
  source = "${path.module}/../../../docker/run.sh"
}

# 初期ソース zip をアップロード
# Cloud Build トリガーと GCS 通知の作成後にアップロードすることで、
# 初回 apply 時にもアップロード検知 → 自動デプロイが走るようにする
resource "google_storage_bucket_object" "source" {
  name   = "${var.app_name}/source.zip"
  bucket = google_storage_bucket.source.name
  source = var.source_zip_path

  depends_on = [
    google_storage_notification.source_upload,
    google_cloudbuild_trigger.deploy,
  ]
}

# GCS → Pub/Sub 通知
resource "google_pubsub_topic" "source_upload" {
  name = "${local.name}-source-upload"
}

# GCS サービスアカウントに Pub/Sub パブリッシャー権限を付与
resource "google_pubsub_topic_iam_member" "gcs_publisher" {
  topic  = google_pubsub_topic.source_upload.name
  role   = "roles/pubsub.publisher"
  member = "serviceAccount:service-${var.project_number}@gs-project-accounts.iam.gserviceaccount.com"
}

# gakusyoku-app/ 配下への OBJECT_FINALIZE を検知
resource "google_storage_notification" "source_upload" {
  bucket             = google_storage_bucket.source.name
  payload_format     = "JSON_API_V1"
  topic              = google_pubsub_topic.source_upload.id
  event_types        = ["OBJECT_FINALIZE"]
  object_name_prefix = "${var.app_name}/"

  depends_on = [google_pubsub_topic_iam_member.gcs_publisher]
}
