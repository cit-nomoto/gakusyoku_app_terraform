# --- Cloud Build トリガー実行用 SA（グループ専用） ---
# 権限はできる限り自グループの資源に限定して付与する。
# プロジェクト全体のロールは他グループの資源にも及ぶため原則使わない。

resource "google_service_account" "cloud_build_trigger" {
  account_id   = "${local.name}-bt"
  display_name = "Cloud Build trigger SA for ${local.name}"
}

# 自グループの Docker リポジトリへの push 権限
resource "google_artifact_registry_repository_iam_member" "cloud_build_artifact_writer" {
  location   = google_artifact_registry_repository.main.location
  repository = google_artifact_registry_repository.main.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.cloud_build_trigger.email}"
}

# 自グループの Cloud Run サービスへのデプロイ権限
resource "google_cloud_run_v2_service_iam_member" "cloud_build_run_developer" {
  location = google_cloud_run_v2_service.main.location
  project  = google_cloud_run_v2_service.main.project
  name     = google_cloud_run_v2_service.main.name
  role     = "roles/run.developer"
  member   = "serviceAccount:${google_service_account.cloud_build_trigger.email}"
}

# デプロイ時に自グループのランタイム SA を割り当てるための権限
resource "google_service_account_iam_member" "cloud_build_sa_user" {
  service_account_id = google_service_account.app.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.cloud_build_trigger.email}"
}

# ビルドログの書き込み権限（logging = CLOUD_LOGGING_ONLY のため必要）
resource "google_project_iam_member" "cloud_build_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.cloud_build_trigger.email}"
}

# 自グループのソースバケットの読み取り権限
resource "google_storage_bucket_iam_member" "cloud_build_source_reader" {
  bucket = google_storage_bucket.source.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.cloud_build_trigger.email}"
}

# 自グループの DB バケットへの権限（デプロイ時のレプリカ削除用 → Step 5）
resource "google_storage_bucket_iam_member" "cloud_build_db_admin" {
  bucket = google_storage_bucket.db.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.cloud_build_trigger.email}"
}

# --- Cloud Build Pub/Sub トリガー ---

resource "google_cloudbuild_trigger" "deploy" {
  name            = "${local.name}-deploy"
  description     = "GCS へのソースアップロードをトリガーに ${local.service_name} をデプロイする"
  service_account = google_service_account.cloud_build_trigger.name

  pubsub_config {
    topic = google_pubsub_topic.source_upload.id
  }

  build {
    # Step 1: Dockerfile/litestream.yml/run.sh を GCS からダウンロード
    step {
      name       = "gcr.io/google.com/cloudsdktool/cloud-sdk"
      entrypoint = "bash"
      args = [
        "-c",
        "mkdir -p /workspace/docker && gsutil -m cp gs://${google_storage_bucket.source.name}/config/Dockerfile gs://${google_storage_bucket.source.name}/config/litestream.yml gs://${google_storage_bucket.source.name}/config/run.sh /workspace/docker/"
      ]
    }

    # Step 2: アプリソース source.zip を GCS からダウンロード・展開
    # オペレータは gs://<bucket>/gakusyoku-app/source.zip にアップロードすること
    # source.zip の内容は gakusyoku_app/ 以下のファイルをルートに配置すること
    # (例: main.py, models.py, requirements.txt, routes/, static/, templates/)
    step {
      name       = "gcr.io/google.com/cloudsdktool/cloud-sdk"
      entrypoint = "bash"
      args = [
        "-c",
        "mkdir -p /workspace/gakusyoku_app && gsutil cp gs://${google_storage_bucket.source.name}/${var.app_name}/source.zip /workspace/source.zip && apt-get install -y unzip -qq && unzip -o /workspace/source.zip -d /workspace/gakusyoku_app"
      ]
    }

    # Step 3: Docker イメージをビルド
    step {
      name = "gcr.io/cloud-builders/docker"
      args = ["build", "-f", "docker/Dockerfile", "-t", local.image, "."]
    }

    # Step 4: Artifact Registry にプッシュ
    step {
      name = "gcr.io/cloud-builders/docker"
      args = ["push", local.image]
    }

    # Step 5: DB レプリカを削除する
    # デプロイのたびに DB を source.zip 同梱の instance/app.db（シードデータ）に
    # リセットするため。レプリカが無い状態で新リビジョンが起動すると、
    # run.sh が同梱 DB をそのまま使う（→ docker/run.sh）。
    # 初回ビルド等でレプリカが存在しない場合もあるため失敗は無視する。
    step {
      name       = "gcr.io/google.com/cloudsdktool/cloud-sdk"
      entrypoint = "bash"
      args = [
        "-c",
        "gsutil -m rm -r gs://${google_storage_bucket.db.name}/app.db || true"
      ]
    }

    # Step 6: Cloud Run にデプロイ
    step {
      name       = "gcr.io/google.com/cloudsdktool/cloud-sdk"
      entrypoint = "gcloud"
      args = [
        "run", "deploy", google_cloud_run_v2_service.main.name,
        "--image", local.image,
        "--region", var.region,
        "--project", var.project_id,
      ]
    }

    options {
      logging = "CLOUD_LOGGING_ONLY"
    }
  }
}
