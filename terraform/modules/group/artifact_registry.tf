# グループ専用の Docker リポジトリ
# リポジトリをグループごとに分けることで、あるグループのビルド SA が
# 他グループのイメージを上書きできないようにする

resource "google_artifact_registry_repository" "main" {
  location      = var.region
  repository_id = local.name
  format        = "DOCKER"

  # ビルドのたびに app:latest へ上書き push され、古いイメージはタグ無しで残り続ける。
  # ストレージ課金が積み上がるのを防ぐため、タグ無しイメージを自動削除する。
  # 猶予を 1 日設けるのは、連続アップロード時に並走したビルドが
  # タグを外された直後のダイジェストをデプロイするケースを保護するため。
  cleanup_policies {
    id     = "delete-untagged"
    action = "DELETE"

    condition {
      tag_state  = "UNTAGGED"
      older_than = "86400s" # 1 日
    }
  }
}

locals {
  image = "${google_artifact_registry_repository.main.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.main.repository_id}/app:latest"
}
