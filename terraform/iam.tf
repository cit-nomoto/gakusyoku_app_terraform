# --- プロジェクト共有のカスタムロール ---

# Console 導線用の一覧権限カスタムロール
# Console の「Cloud Storage > バケット」「Cloud Run > サービス」の一覧ページには
# プロジェクトレベルの list 権限が必要だが、これだけを持つ事前定義ロールが無いため自作する。
# 一覧では他グループの資源名も見えるが、中身へのアクセス権は無い（講義用途では許容）。
# 注意: カスタムロールは削除後 7 日間は同じ role_id で再作成できない（destroy → 即 apply に注意）
resource "google_project_iam_custom_role" "console_lister" {
  role_id     = "consoleLister"
  title       = "Console Lister"
  description = "バケット・Cloud Run サービスの一覧閲覧のみ（Console で自グループの資源にたどり着くため）"
  permissions = [
    "storage.buckets.list",
    "run.services.list",
    "run.locations.list",
  ]
}
