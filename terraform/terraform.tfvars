# =============================================================================
# 変数の実際の値（terraform.tfvars）
# =============================================================================
# このファイルは variables.tf で定義した変数に実際の値を設定する
# 環境ごとに値を変えたい場合は dev.tfvars / prod.tfvars のように分ける
#
# ⚠️ シークレット情報（パスワード等）はここに書かず、
#    環境変数（TF_VAR_xxx）や AWS Secrets Manager を使うこと

project_name = "taskmanagement"
environment  = "dev"
aws_region   = "ap-northeast-1"

# =============================================================================
# Phase 5: 独自ドメイン設定
# =============================================================================
# ドメインを取得したら以下のコメントを外して値を設定し terraform apply を実行する
# domain_name = "example.com"   ← 取得したドメインに変更する
domain_name = ""  # 空文字 = HTTP のみ（HTTPS・ACM・Route 53 は無効）

vpc_cidr             = "10.0.0.0/16"
availability_zones   = ["ap-northeast-1a", "ap-northeast-1c"]
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]

# =============================================================================
# RDS 設定
# =============================================================================
db_instance_class        = "db.t3.micro"    # 無料枠対象
db_allocated_storage     = 20               # 無料枠の上限 20GB
db_name                  = "taskmanagement"
db_username              = "postgres"
# db_password は機密情報のため terraform.tfvars には書かない
# 以下の方法で渡す:
#   export TF_VAR_db_password="your-secure-password"
#   terraform plan
db_backup_retention_days = 7
db_deletion_protection   = false
db_skip_final_snapshot   = true             # 学習中は削除しやすいように true

# =============================================================================
# ECS 設定（Phase 4）
# =============================================================================
backend_cpu            = 512    # 0.5 vCPU（Spring Boot に必要な最低限）
backend_memory         = 1024   # 1GB
backend_desired_count  = 1      # 学習中はコスト削減のため1台

frontend_cpu           = 256    # 0.25 vCPU（Nginx は軽量）
frontend_memory        = 512    # 512MB
frontend_desired_count = 1
