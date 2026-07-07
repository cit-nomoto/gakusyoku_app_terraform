# --- operators IAM バインディング（グループ内オペレータのみ） ---
# すべて自グループの資源に限定して付与する

# ソースバケットへの書き込み権限
# gakusyoku-app/ プレフィックス配下のみアップロード可能
# （config/ 配下の Dockerfile 等をオペレータが書き換えられないようにする）
resource "google_storage_bucket_iam_member" "operators_source_upload" {
  for_each = toset(var.operators)

  bucket = google_storage_bucket.source.name
  role   = "roles/storage.objectUser"
  member = "user:${each.value}"

  condition {
    title      = "${var.app_name} prefix only"
    expression = "resource.name.startsWith(\"projects/_/buckets/${google_storage_bucket.source.name}/objects/${var.app_name}/\")"
  }
}

# バケット内オブジェクトの一覧・閲覧権限（バケット一覧は与えない）
# Console で直接 URL を開いてオブジェクトを確認できるようにする
# roles/storage.legacyBucketReader = storage.buckets.get + storage.objects.list + storage.objects.get
resource "google_storage_bucket_iam_member" "operators_source_reader" {
  for_each = toset(var.operators)

  bucket = google_storage_bucket.source.name
  role   = "roles/storage.legacyBucketReader"
  member = "user:${each.value}"
}

# DB レプリカバケットへのオブジェクト読み書き・削除権限
# オペレータが自グループの DB データを消したり差し替えたりできるようにする
# （レプリカ削除後、Cloud Run インスタンスが再起動すると空の DB で立ち上がる）
resource "google_storage_bucket_iam_member" "operators_db_user" {
  for_each = toset(var.operators)

  bucket = google_storage_bucket.db.name
  role   = "roles/storage.objectUser"
  member = "user:${each.value}"
}

# Console でバケットを開けるようにするための閲覧権限（source バケットと同様）
resource "google_storage_bucket_iam_member" "operators_db_reader" {
  for_each = toset(var.operators)

  bucket = google_storage_bucket.db.name
  role   = "roles/storage.legacyBucketReader"
  member = "user:${each.value}"
}

# 自グループの Cloud Run サービスの閲覧権限（サービス単位で付与）
resource "google_cloud_run_v2_service_iam_member" "operators_run_viewer" {
  for_each = toset(var.operators)

  location = google_cloud_run_v2_service.main.location
  project  = google_cloud_run_v2_service.main.project
  name     = google_cloud_run_v2_service.main.name
  role     = "roles/run.viewer"
  member   = "user:${each.value}"
}

# バケット・Cloud Run サービス一覧の閲覧権限（プロジェクト単位・カスタムロール）
# Console の一覧ページから自グループの資源にたどり着けるようにする。
# 他グループの資源名も見えるが中身は開けない。
resource "google_project_iam_member" "operators_console_lister" {
  for_each = toset(var.operators)

  project = var.project_id
  role    = var.console_lister_role
  member  = "user:${each.value}"
}

# ビルド履歴の閲覧権限（プロジェクト単位）
# Cloud Build のビルド・トリガーには資源単位の IAM が無いためプロジェクトレベルで付与する。
# 他グループのビルド履歴も閲覧できるが、講義用途では許容する（ログ閲覧と同じ整理）。
resource "google_project_iam_member" "operators_build_viewer" {
  for_each = toset(var.operators)

  project = var.project_id
  role    = "roles/cloudbuild.builds.viewer"
  member  = "user:${each.value}"
}

# ログ閲覧権限（プロジェクト単位）
# GCP にはサービス単位のログ閲覧権限がないためプロジェクトレベルで付与する。
# 他グループのログも読み取りできるが、講義用途では許容する。
# 自グループのログはロギングクエリ（service_name で絞り込み）で参照する。
resource "google_project_iam_member" "operators_log_viewer" {
  for_each = toset(var.operators)

  project = var.project_id
  role    = "roles/logging.viewer"
  member  = "user:${each.value}"
}
