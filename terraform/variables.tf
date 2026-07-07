variable "project_id" {
  description = "GCP プロジェクト ID（terraform.tfvars で指定）"
  type        = string
}

variable "region" {
  description = "デプロイリージョン"
  type        = string
  default     = "asia-northeast1"
}

variable "app_name" {
  description = "アプリケーション名（リソース名のプレフィックスに使用）"
  type        = string
  default     = "gakusyoku-app"
}

variable "groups" {
  description = <<-EOT
    学生のグループ定義（グループ名 => メールアドレスのリスト）。
    グループごとに GCS バケット・Cloud Run・Cloud Build 等の資源一式が作成され、
    各学生は自分のグループの資源にのみアクセスできる。
  EOT
  type        = map(list(string))
  default     = {}

  validation {
    # サービスアカウント ID（app_name + グループ名 + サフィックスで 30 文字以内）の制約上、
    # グループ名は小文字英数字とハイフンで 12 文字以内に制限する
    condition = alltrue([
      for name in keys(var.groups) : can(regex("^[a-z]([a-z0-9-]{0,10}[a-z0-9])?$", name))
    ])
    error_message = "グループ名は小文字英字始まり・小文字英数字とハイフンのみ・12 文字以内にしてください。"
  }
}
