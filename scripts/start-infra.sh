#!/bin/bash
# =============================================================================
# scripts/start-infra.sh
# =============================================================================
# AWS インフラを起動して、アプリが使える状態にするスクリプト
#
# 実行すること:
#   1. terraform apply（VPC・RDS・ECS・ALB・NAT GW などを作成）
#   2. Docker イメージをビルドして ECR にプッシュ
#   3. ECS サービスを強制再デプロイ（新しいイメージで起動）
#   4. アプリの URL を表示
#
# 使い方:
#   export TF_VAR_db_password="your-password"
#   ./scripts/start-infra.sh
#
# 所要時間: 約 20〜30 分

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TERRAFORM_DIR="${PROJECT_ROOT}/terraform"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# =============================================================================
# 前提条件チェック
# =============================================================================

log_info "前提条件を確認しています..."

if [[ -z "${TF_VAR_db_password:-}" ]]; then
  log_error "DBパスワードが設定されていません。"
  log_error "実行前に以下を設定してください:"
  log_error "  export TF_VAR_db_password=\"your-secure-password\""
  exit 1
fi

for cmd in aws terraform docker git; do
  if ! command -v "$cmd" &>/dev/null; then
    log_error "${cmd} がインストールされていません。"
    exit 1
  fi
done

if ! aws sts get-caller-identity &>/dev/null; then
  log_error "AWS の認証が設定されていません。'aws configure' を実行してください。"
  exit 1
fi

if ! docker info &>/dev/null; then
  log_error "Docker が起動していません。Docker Desktop を起動してください。"
  exit 1
fi

log_success "前提条件チェック OK"
echo ""

# =============================================================================
# Step 1: Terraform でインフラを作成
# =============================================================================

log_info "================================================"
log_info "Step 1/3: terraform apply を実行しています..."
log_info "  ※ NAT Gateway・RDS・ECS・ALB などを作成します"
log_info "  ※ 約 15〜20 分かかります"
log_info "================================================"

cd "${TERRAFORM_DIR}"
terraform init -upgrade -input=false
terraform apply -auto-approve -input=false

log_success "Step 1/3 完了: インフラが作成されました"
echo ""

# =============================================================================
# Step 2: Docker イメージをビルドして ECR にプッシュ
# =============================================================================

log_info "================================================"
log_info "Step 2/3: Docker イメージをビルド & ECR にプッシュ..."
log_info "================================================"

cd "${PROJECT_ROOT}"
./scripts/build-and-push.sh

log_success "Step 2/3 完了: イメージが ECR にプッシュされました"
echo ""

# =============================================================================
# Step 3: ECS サービスを強制再デプロイ
# =============================================================================

log_info "================================================"
log_info "Step 3/3: ECS サービスを再デプロイしています..."
log_info "================================================"

cd "${TERRAFORM_DIR}"
CLUSTER=$(terraform output -raw ecs_cluster_name)
BACKEND_SVC=$(terraform output -raw ecs_backend_service_name)
FRONTEND_SVC=$(terraform output -raw ecs_frontend_service_name)
REGION=$(terraform output -raw aws_region)

# 強制再デプロイ（新しいイメージで ECS タスクを起動し直す）
aws ecs update-service \
  --cluster "$CLUSTER" \
  --service "$BACKEND_SVC" \
  --force-new-deployment \
  --region "$REGION" \
  --output text --query 'service.serviceName' > /dev/null

aws ecs update-service \
  --cluster "$CLUSTER" \
  --service "$FRONTEND_SVC" \
  --force-new-deployment \
  --region "$REGION" \
  --output text --query 'service.serviceName' > /dev/null

log_info "ECS タスクの起動を待っています（最大 5 分）..."

# バックエンドのタスクが安定するまで待つ
aws ecs wait services-stable \
  --cluster "$CLUSTER" \
  --services "$BACKEND_SVC" "$FRONTEND_SVC" \
  --region "$REGION" \
  && log_success "ECS タスクが正常に起動しました" \
  || log_warn "ECS の安定確認がタイムアウトしました。ログを確認してください:"

log_success "Step 3/3 完了: デプロイが完了しました"
echo ""

# =============================================================================
# 完了：アクセス情報を表示
# =============================================================================

APP_URL=$(terraform output -raw app_url 2>/dev/null || echo "取得できませんでした")

echo ""
echo "========================================================"
log_success "インフラの起動が完了しました！"
echo "========================================================"
echo ""
echo "  アプリの URL: ${APP_URL}"
echo ""
echo "  ログの確認:"
echo "    aws logs tail /ecs/taskmanagement/backend --follow --region ${REGION}"
echo "    aws logs tail /ecs/taskmanagement/frontend --follow --region ${REGION}"
echo ""
log_warn "使い終わったら必ず ./scripts/stop-infra.sh を実行してください"
log_warn "（停止しないと課金が続きます）"
