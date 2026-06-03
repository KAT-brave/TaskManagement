# =============================================================================
# 変数定義
# =============================================================================
# variables.tf = Terraformで使う「変数」を定義するファイル
# 実際の値は terraform.tfvars に書くか、コマンド実行時に渡す
# これにより、環境ごと（dev/staging/prod）に値を変えることができる

variable "aws_region" {
  description = "AWSのリージョン（東京 = ap-northeast-1）"
  type        = string
  default     = "ap-northeast-1"
}

variable "project_name" {
  description = "プロジェクト名（リソース名のプレフィックスに使用）"
  type        = string
  default     = "taskmanagement"
}

variable "environment" {
  description = "環境名（dev / staging / prod）"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment は dev, staging, prod のいずれかを指定してください。"
  }
}

variable "vpc_cidr" {
  description = "VPCのCIDRブロック（IPアドレス範囲）"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "使用するアベイラビリティゾーン（AZ）のリスト"
  type        = list(string)
  default     = ["ap-northeast-1a", "ap-northeast-1c"]
}

variable "public_subnet_cidrs" {
  description = "パブリックサブネットのCIDRブロックリスト"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "プライベートサブネットのCIDRブロックリスト（Phase 2 の RDS 用）"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

# =============================================================================
# EC2 関連変数
# =============================================================================

variable "ec2_instance_type" {
  description = "EC2 インスタンスタイプ（t3.micro = 無料枠対象）"
  type        = string
  default     = "t3.micro"
}

variable "ssh_public_key_path" {
  description = <<-EOT
    SSH 公開鍵ファイルのパス
    事前準備: ssh-keygen -t ed25519 -C "taskmanagement" -f ~/.ssh/taskmanagement
    → 公開鍵: ~/.ssh/taskmanagement.pub
  EOT
  type    = string
  default = "~/.ssh/taskmanagement.pub"
}

# =============================================================================
# RDS 関連変数（Phase 2 で使用）
# =============================================================================

variable "db_instance_class" {
  description = "RDSのインスタンスタイプ（db.t3.micro = 無料枠対象）"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "RDSの初期ストレージ容量（GB）。無料枠は20GBまで"
  type        = number
  default     = 20
}

variable "db_name" {
  description = "作成するデータベース名"
  type        = string
  default     = "taskmanagement"
}

variable "db_username" {
  description = "RDSの管理者ユーザー名"
  type        = string
  default     = "postgres"
}

variable "db_password" {
  description = "RDSの管理者パスワード（terraform.tfvarsには書かず、環境変数で渡す）"
  type        = string
  sensitive   = true
  default     = ""
}

variable "db_backup_retention_days" {
  description = "自動バックアップの保持日数（0で無効、最大35日）"
  type        = number
  default     = 7
}

variable "db_deletion_protection" {
  description = "削除保護の有効化（本番はtrue推奨）"
  type        = bool
  default     = false
}

variable "db_skip_final_snapshot" {
  description = "terraform destroy時にスナップショットをスキップするか（学習中はtrue）"
  type        = bool
  default     = true
}
