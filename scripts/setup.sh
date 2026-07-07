#!/bin/bash
#
# 初期構築スクリプト
# Terraform でグループごとのインフラ一式を作成する。
# Cloud Run はプレースホルダイメージで作成され、Terraform が各グループの
# ソースバケットへ source.zip をアップロードすると Cloud Build が
# 実イメージをビルドして自動デプロイする。
# 2 回目以降の手動デプロイは deploy.sh を使う。
#
# 使い方:
#   1. terraform/terraform.tfvars を用意（例: cp terraform/terraform.tfvars.example terraform/terraform.tfvars）
#   2. gcloud auth login / gcloud auth application-default login 済みであること
#   3. ./scripts/setup.sh

set -euo pipefail

cd "$(dirname "$0")/.."
TF_DIR="terraform"

# 前提コマンドの確認
need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: '$1' が見つかりません。インストールしてください。" >&2
    exit 1
  }
}
need terraform
need gcloud

# tfvars の確認
if [[ ! -f "${TF_DIR}/terraform.tfvars" ]]; then
  echo "ERROR: ${TF_DIR}/terraform.tfvars がありません。" >&2
  echo "  cp ${TF_DIR}/terraform.tfvars.example ${TF_DIR}/terraform.tfvars" >&2
  echo "  を実行し、project_id などを設定してから再実行してください。" >&2
  exit 1
fi

echo "==> [1/3] Terraform init"
terraform -chdir="${TF_DIR}" init -input=false

echo "==> [2/3] Terraform apply"
terraform -chdir="${TF_DIR}" apply -input=false -auto-approve

echo "==> [3/3] 完了"
echo "初回デプロイは Cloud Build が実行中です。数分後に以下の URL で確認してください。"
echo "グループごとの Service URL:"
terraform -chdir="${TF_DIR}" output -json urls
echo "グループごとのソースアップロード先バケット:"
terraform -chdir="${TF_DIR}" output -json source_buckets
