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

vpc_cidr             = "10.0.0.0/16"
availability_zones   = ["ap-northeast-1a", "ap-northeast-1c"]
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
