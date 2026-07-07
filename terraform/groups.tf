# --- グループごとの資源一式 ---
# var.groups の 1 エントリにつき modules/group を 1 セット作成する。
# 各グループには専用の GCS バケット・Artifact Registry・Cloud Run・
# Cloud Build トリガー・IAM が作成され、オペレータは自グループの資源にのみ触れる。

# Terraform 実行ユーザー（各グループのソースバケットに管理権限を付与する）
data "google_client_openid_userinfo" "terraform_runner" {}

module "group" {
  source   = "./modules/group"
  for_each = var.groups

  project_id             = data.google_project.project.project_id
  project_number         = data.google_project.project.number
  region                 = var.region
  app_name               = var.app_name
  group_name             = each.key
  operators              = each.value
  source_zip_path        = "${path.module}/../source.zip" # リポジトリ直下の初期ソース zip（中身は gakusyoku_app）
  console_lister_role    = google_project_iam_custom_role.console_lister.id
  terraform_runner_email = data.google_client_openid_userinfo.terraform_runner.email

  depends_on = [
    google_project_service.artifact_registry,
    google_project_service.cloud_run,
    google_project_service.cloud_build,
    google_project_service.pubsub,
  ]
}
