# 手動デプロイスクリプト（PowerShell 版・グループ単位）
# 使い方: .\scripts\deploy.ps1 <group>
#   例: .\scripts\deploy.ps1 team-a
# プロジェクト等を上書きする場合は環境変数 PROJECT_ID / REGION / APP_NAME を設定する。

param(
    [string]$Group
)

$ErrorActionPreference = "Stop"

Set-Location (Join-Path $PSScriptRoot "..")

if (-not $Group) {
    Write-Host "ERROR: グループ名を指定してください。" -ForegroundColor Red
    Write-Host "  例: .\scripts\deploy.ps1 team-a"
    exit 1
}

# gcloud config より project を取得
$ProjectId = $env:PROJECT_ID
if (-not $ProjectId) {
    $ProjectId = (gcloud config get-value project 2>$null | Out-String).Trim()
    if ($ProjectId -eq "(unset)") { $ProjectId = "" }
}
$Region = if ($env:REGION) { $env:REGION } else { "asia-northeast1" }
$AppName = if ($env:APP_NAME) { $env:APP_NAME } else { "gakusyoku-app" }

if (-not $ProjectId) {
    Write-Host "ERROR: PROJECT_ID が未設定で、gcloud のデフォルトプロジェクトもありません。" -ForegroundColor Red
    Write-Host '  $env:PROJECT_ID = "your-project" を設定してから再実行してください。'
    exit 1
}

$Image = "$Region-docker.pkg.dev/$ProjectId/$AppName-$Group/app:latest"
$Service = "$AppName-$Group-lite"

Write-Host "==> Target: project=$ProjectId region=$Region service=$Service"

# Cloud Build を用いて image を作成、push
Write-Host "==> Cloud Build build & push"
gcloud builds submit `
    --project "$ProjectId" `
    --config scripts/cloudbuild.yaml `
    --substitutions "_IMAGE=$Image" `
    .
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "==> Cloud Run deploy"
gcloud run deploy "$Service" `
    --image "$Image" `
    --region "$Region" `
    --project "$ProjectId"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "==> Done!"
