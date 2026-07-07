# 初期構築スクリプト（PowerShell 版）
# Terraform でグループごとのインフラ一式を作成する。
# Cloud Run はプレースホルダイメージで作成され、Terraform が各グループの
# ソースバケットへ source.zip をアップロードすると Cloud Build が
# 実イメージをビルドして自動デプロイする。
# 2 回目以降の手動デプロイは deploy.ps1 を使う。
#
# 使い方:
#   1. terraform/terraform.tfvars を用意（例: Copy-Item terraform/terraform.tfvars.example terraform/terraform.tfvars）
#   2. gcloud auth login / gcloud auth application-default login 済みであること
#   3. .\scripts\setup.ps1

$ErrorActionPreference = "Stop"

Set-Location (Join-Path $PSScriptRoot "..")
$TfDir = "terraform"

# 前提コマンドの確認
foreach ($cmd in @("terraform", "gcloud")) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Host "ERROR: '$cmd' が見つかりません。インストールしてください。" -ForegroundColor Red
        exit 1
    }
}

# tfvars の確認
if (-not (Test-Path "$TfDir/terraform.tfvars")) {
    Write-Host "ERROR: $TfDir/terraform.tfvars がありません。" -ForegroundColor Red
    Write-Host "  Copy-Item $TfDir/terraform.tfvars.example $TfDir/terraform.tfvars"
    Write-Host "  を実行し、project_id などを設定してから再実行してください。"
    exit 1
}

Write-Host "==> [1/3] Terraform init"
terraform -chdir="$TfDir" init -input=false
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "==> [2/3] Terraform apply"
terraform -chdir="$TfDir" apply -input=false -auto-approve
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "==> [3/3] 完了"
Write-Host "初回デプロイは Cloud Build が実行中です。数分後に以下の URL で確認してください。"
Write-Host "グループごとの Service URL:"
terraform -chdir="$TfDir" output -json urls
Write-Host "グループごとのソースアップロード先バケット:"
terraform -chdir="$TfDir" output -json source_buckets
