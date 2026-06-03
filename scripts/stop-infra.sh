#!/bin/bash
# =============================================================================
# scripts/stop-infra.sh
# =============================================================================
# AWS インフラをすべて削除して課金を止めるスクリプト
#
# 削除されるもの:
#   - ECS タスク・サービス・クラスター
#   - ALB・ターゲットグループ
#   - NAT Gateway・EIP
#   - RDS（スナップショットなし: skip_final_snapshot = true）
#   - VPC・サブネット・セキュリティグループ
#   - ECR リポジトリ（イメージは残る設定）
#
# 削除されないもの:
#   - ECR のイメージ（ライフサイクルポリシーに従う）
#   - CloudWatch Logs（30日後に自動削除）
#   - S3 に保存した tfstate（使っている場合）
#
# ⚠️  このスクリプトはすべての AWS リソースを削除します
#     データは失われます（RDS のデータも消えます）
#
# 使い方:
#   export TF_VAR_db_password="your-password"  # apply時と同じパスワード
#   ./scripts/stop-infra.sh

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
# 確認プロンプト
# =============================================================================

echo ""
echo "========================================================"
log_warn "WARNING: AWS リソースをすべて削除します"
echo "========================================================"
echo ""
echo "  削除されるリソース:"
echo "    - ECS（コンテナ）"
echo "    - ALB（ロードバランサー）"
echo "    - NAT Gateway + EIP"
echo "    - RDS（データベース）※ データも削除されます"
echo "    - VPC・ネットワーク全体"
echo ""
log_warn "RDS のデータは失われます。必要なデータは事前にバックアップしてください。"
echo ""

read -rp "本当に削除しますか？ (yes と入力して Enter): " CONFIRM
if [[ "${CONFIRM}" != "yes" ]]; then
  log_info "キャンセルしました。"
  exit 0
fi

# =============================================================================
# 前提条件チェック
# =============================================================================

if [[ -z "${TF_VAR_db_password:-}" ]]; then
  log_error "DBパスワードが設定されていません。"
  log_error "  export TF_VAR_db_password=\"your-secure-password\""
  exit 1
fi

if ! aws sts get-caller-identity &>/dev/null; then
  log_error "AWS の認証が設定されていません。"
  exit 1
fi

# =============================================================================
# ECS タスク数を 0 に減らしてから destroy（削除の高速化）
# =============================================================================

log_info "ECS タスクを停止しています（destroy 高速化のため）..."

cd "${TERRAFORM_DIR}"

# Terraform の出力値が取れる場合のみ実行
if CLUSTER=$(terraform output -raw ecs_cluster_name 2>/dev/null); then
  REGION=$(terraform output -raw aws_region 2>/dev/null || echo "ap-northeast-1")
  BACKEND_SVC=$(terraform output -raw ecs_backend_service_name 2>/dev/null)
  FRONTEND_SVC=$(terraform output -raw ecs_frontend_service_name 2>/dev/null)

  # desired_count を 0 にしてタスクを停止
  aws ecs update-service \
    --cluster "$CLUSTER" \
    --service "$BACKEND_SVC" \
    --desired-count 0 \
    --region "$REGION" \
    --output text --query 'service.serviceName' > /dev/null 2>&1 || true

  aws ecs update-service \
    --cluster "$CLUSTER" \
    --service "$FRONTEND_SVC" \
    --desired-count 0 \
    --region "$REGION" \
    --output text --query 'service.serviceName' > /dev/null 2>&1 || true

  log_info "タスクが停止するまで少し待ちます..."
  sleep 15
fi

# =============================================================================
# terraform destroy
# =============================================================================

log_info "================================================"
log_info "terraform destroy を実行しています..."
log_info "  ※ 約 10〜15 分かかります"
log_info "================================================"

terraform destroy -auto-approve -input=false

# =============================================================================
# 完了
# =============================================================================

echo ""
echo "========================================================"
log_success "すべての AWS リソースを削除しました"
echo "========================================================"
echo ""
echo "  課金が止まります（削除から数分で反映）"
echo ""
echo "  次回起動するときは:"
echo "    export TF_VAR_db_password=\"your-password\""
echo "    ./scripts/start-infra.sh"
echo ""
log_info "念のため AWS コンソールで残っているリソースがないか確認してください"
log_info "  https://ap-northeast-1.console.aws.amazon.com/billing/home#/bills"
