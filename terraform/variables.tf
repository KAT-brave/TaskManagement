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
  # 10.0.0.0/16 = 10.0.0.0〜10.0.255.255 の約65,000個のIPアドレスが使える
}

variable "availability_zones" {
  description = "使用するアベイラビリティゾーン（AZ）のリスト"
  type        = list(string)
  default     = ["ap-northeast-1a", "ap-northeast-1c"]
  # ap-northeast-1a = 東京のデータセンターA棟
  # ap-northeast-1c = 東京のデータセンターC棟
  # 2つに分散することで、片方が障害になっても継続稼働できる
}

variable "public_subnet_cidrs" {
  description = "パブリックサブネットのCIDRブロックリスト（AZの数と一致させる）"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
  # 10.0.1.0/24 = 10.0.1.0〜10.0.1.255（256個）
}

variable "private_subnet_cidrs" {
  description = "プライベートサブネットのCIDRブロックリスト（AZの数と一致させる）"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}
