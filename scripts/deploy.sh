#!/bin/bash
#
# 手動デプロイスクリプト（グループ単位）
# 使い方: ./scripts/deploy.sh <group>
#   例: ./scripts/deploy.sh team-a

set -euo pipefail
cd "$(dirname "$0")/.."

GROUP="${1:-}"
if [[ -z "${GROUP}" ]]; then
  echo "ERROR: グループ名を指定してください。" >&2
  echo "  例: ./scripts/deploy.sh team-a" >&2
  exit 1
fi

# gcloud configよりprojectを取得
PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}"
REGION="${REGION:-asia-northeast1}"
APP_NAME="${APP_NAME:-gakusyoku-app}"

if [[ -z "${PROJECT_ID}" ]]; then
  echo "ERROR: PROJECT_ID が未設定で、gcloud のデフォルトプロジェクトもありません。" >&2
  echo "  PROJECT_ID=your-project ./scripts/deploy.sh <group> のように指定してください。" >&2
  exit 1
fi

IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/${APP_NAME}-${GROUP}/app:latest"
SERVICE="${APP_NAME}-${GROUP}-lite"

echo "==> Target: project=${PROJECT_ID} region=${REGION} service=${SERVICE}"

# cloud buildを用いてimageを作成、push
echo "==> Cloud Build build & push"
gcloud builds submit \
  --project "${PROJECT_ID}" \
  --config scripts/cloudbuild.yaml \
  --substitutions "_IMAGE=${IMAGE}" \
  .

echo "==> Cloud Run deploy"
gcloud run deploy "${SERVICE}" \
  --image "${IMAGE}" \
  --region "${REGION}" \
  --project "${PROJECT_ID}"

echo "==> Done!"
