variable "project_id" {
  description = "GCP プロジェクト ID"
  type        = string
}

variable "project_number" {
  description = "GCP プロジェクト番号（GCS サービスアカウントの特定に使用）"
  type        = string
}

variable "region" {
  description = "デプロイリージョン"
  type        = string
}

variable "app_name" {
  description = "アプリケーション名（リソース名のプレフィックスに使用）"
  type        = string
}

variable "group_name" {
  description = "グループ名（リソース名に使用。小文字英数字とハイフン、12 文字以内）"
  type        = string
}

variable "operators" {
  description = "このグループの運用担当者のメールアドレス"
  type        = list(string)
}

variable "source_zip_path" {
  description = "初期デプロイ用アプリソース zip のローカルパス"
  type        = string
}

variable "console_lister_role" {
  description = "Console 導線用の一覧閲覧カスタムロールの ID（projects/<project>/roles/... 形式）"
  type        = string
}

variable "terraform_runner_email" {
  description = "Terraform 実行ユーザーのメールアドレス（ソースバケットの管理権限を付与）"
  type        = string
}

locals {
  # このグループの資源名プレフィックス（例: gakusyoku-app-team-a）
  name = "${var.app_name}-${var.group_name}"

  service_name = "${local.name}-run"
}
