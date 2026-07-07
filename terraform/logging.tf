# --- 監査用ログバケット（プロジェクトに 1 つ） ---
# 全グループの Cloud Run ログをシンクで集約する。
# アクセス制御用ではなく、ログの整理・保全（監査）用。
# ログは _Default バケットとこのバケットの両方に保存される。

resource "google_logging_project_bucket_config" "app" {
  project        = var.project_id
  location       = "global"
  bucket_id      = "${var.app_name}-logs"
  retention_days = 90 # 監査用のため _Default（30 日）より長く保持する
}

# Cloud Run のログをログバケットへルーティング
# （同一プロジェクト内のログバケット宛てのため、追加の権限付与は不要）
resource "google_logging_project_sink" "app" {
  name        = "${var.app_name}-logs"
  destination = "logging.googleapis.com/${google_logging_project_bucket_config.app.id}"
  filter      = "resource.type=\"cloud_run_revision\""
}
