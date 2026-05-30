#!/bin/bash
# =============================================================================
# scripts/build-and-push.sh
# =============================================================================
# Docker イメージをビルドして ECR にプッシュするスクリプト
#
# 使い方:
#   ./scripts/build-and-push.sh [オプション]
#
# オプション:
#   --backend-only   バックエンドだけビルド&プッシュ
#   --frontend-only  フロントエンドだけビルド&プッシュ
#   --tag <TAG>      イメージタグを指定（デフォルト: git の短縮コミットハッシュ）
#
# 例:
#   ./scripts/build-and-push.sh
#   ./scripts/build-and-push.sh --backend-only
#   ./scripts/build-and-push.sh --tag v1.0.0

set -euo pipefail
# set -e: コマンドが失敗したらスクリプトを即終了
# set -u: 未定義の変数を参照したらエラー
# set -o pipefail: パイプの途中でのエラーを検知

# =============================================================================
# 設定
# =============================================================================

# スクリプトの場所からプロジェクトルートを算出
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Terraform の出力値から ECR リポジトリ URL を取得する
TERRAFORM_DIR="${PROJECT_ROOT}/terraform"

# =============================================================================
# 色付きログ出力
# =============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# =============================================================================
# 引数パース
# =============================================================================

BUILD_BACKEND=true
BUILD_FRONTEND=true
IMAGE_TAG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --backend-only)  BUILD_FRONTEND=false; shift ;;
    --frontend-only) BUILD_BACKEND=false;  shift ;;
    --tag)           IMAGE_TAG="$2";       shift 2 ;;
    *)               log_error "不明なオプション: $1"; exit 1 ;;
  esac
done

# タグが指定されていない場合は git のショートコミットハッシュを使う
if [[ -z "${IMAGE_TAG}" ]]; then
  IMAGE_TAG="sha-$(git -C "${PROJECT_ROOT}" rev-parse --short HEAD)"
fi

log_info "イメージタグ: ${IMAGE_TAG}"

# =============================================================================
# 前提条件チェック
# =============================================================================

log_info "前提条件を確認しています..."

# Docker が起動しているか
if ! docker info &>/dev/null; then
  log_error "Docker が起動していません。Docker Desktop を起動してください。"
  exit 1
fi

# AWS CLI がインストールされているか
if ! command -v aws &>/dev/null; then
  log_error "AWS CLI がインストールされていません。"
  log_error "インストール: brew install awscli"
  exit 1
fi

# AWS 認証が設定されているか
if ! aws sts get-caller-identity &>/dev/null; then
  log_error "AWS の認証が設定されていません。"
  log_error "設定方法: aws configure"
  exit 1
fi

# Terraform がインストールされているか
if ! command -v terraform &>/dev/null; then
  log_error "Terraform がインストールされていません。"
  log_error "インストール: brew install hashicorp/tap/terraform"
  exit 1
fi

log_success "前提条件チェック OK"

# =============================================================================
# Terraform の出力から ECR URL を取得
# =============================================================================

log_info "Terraform の出力から ECR リポジトリ URL を取得しています..."

cd "${TERRAFORM_DIR}"

# terraform output コマンドで値を取得
# -raw: 引用符なしで値を出力する
AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || echo "ap-northeast-1")
BACKEND_REPO=$(terraform output -raw ecr_backend_repository_url 2>/dev/null)
FRONTEND_REPO=$(terraform output -raw ecr_frontend_repository_url 2>/dev/null)
REGISTRY_URL=$(terraform output -raw ecr_registry_url 2>/dev/null)

if [[ -z "${BACKEND_REPO}" ]] || [[ -z "${FRONTEND_REPO}" ]]; then
  log_error "ECR リポジトリ URL が取得できませんでした。"
  log_error "先に 'terraform apply' を実行して ECR リポジトリを作成してください。"
  exit 1
fi

log_success "バックエンド ECR: ${BACKEND_REPO}"
log_success "フロントエンド ECR: ${FRONTEND_REPO}"

cd "${PROJECT_ROOT}"

# =============================================================================
# ECR へのログイン
# =============================================================================

log_info "ECR にログインしています..."

# aws ecr get-login-password: ECR の認証トークン（12時間有効）を取得
# docker login: そのトークンで Docker を認証する
aws ecr get-login-password --region "${AWS_REGION}" \
  | docker login --username AWS --password-stdin "${REGISTRY_URL}"

log_success "ECR ログイン OK"

# =============================================================================
# バックエンドのビルド & プッシュ
# =============================================================================

if [[ "${BUILD_BACKEND}" == "true" ]]; then
  log_info "========================================"
  log_info "バックエンド (Spring Boot) をビルド中..."
  log_info "========================================"

  cd "${PROJECT_ROOT}/backend"

  docker build \
    --platform linux/amd64 \
    --tag "${BACKEND_REPO}:${IMAGE_TAG}" \
    --tag "${BACKEND_REPO}:latest" \
    .
  # --platform linux/amd64:
  #   M1/M2 Mac（ARM）でビルドする場合でも、ECS（x86_64）用のイメージを作成する
  #   これを指定しないと「exec format error」でコンテナが起動しない

  log_info "バックエンドイメージを ECR にプッシュ中..."
  docker push "${BACKEND_REPO}:${IMAGE_TAG}"
  docker push "${BACKEND_REPO}:latest"

  log_success "バックエンド プッシュ完了: ${BACKEND_REPO}:${IMAGE_TAG}"

  cd "${PROJECT_ROOT}"
fi

# =============================================================================
# フロントエンドのビルド & プッシュ
# =============================================================================

if [[ "${BUILD_FRONTEND}" == "true" ]]; then
  log_info "========================================"
  log_info "フロントエンド (React + Nginx) をビルド中..."
  log_info "========================================"

  cd "${PROJECT_ROOT}/frontend"

  docker build \
    --platform linux/amd64 \
    --tag "${FRONTEND_REPO}:${IMAGE_TAG}" \
    --tag "${FRONTEND_REPO}:latest" \
    .

  log_info "フロントエンドイメージを ECR にプッシュ中..."
  docker push "${FRONTEND_REPO}:${IMAGE_TAG}"
  docker push "${FRONTEND_REPO}:latest"

  log_success "フロントエンド プッシュ完了: ${FRONTEND_REPO}:${IMAGE_TAG}"

  cd "${PROJECT_ROOT}"
fi

# =============================================================================
# 完了
# =============================================================================

echo ""
log_success "========================================"
log_success "すべてのイメージのプッシュが完了しました"
log_success "========================================"
echo ""
log_info "ECR にプッシュされたイメージ:"
if [[ "${BUILD_BACKEND}" == "true" ]]; then
  echo "  バックエンド : ${BACKEND_REPO}:${IMAGE_TAG}"
fi
if [[ "${BUILD_FRONTEND}" == "true" ]]; then
  echo "  フロントエンド: ${FRONTEND_REPO}:${IMAGE_TAG}"
fi
echo ""
log_info "次のステップ（Phase 4）: ECS Fargate でコンテナを起動する"
