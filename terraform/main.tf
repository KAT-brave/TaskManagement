# =============================================================================
# Terraform 設定・プロバイダー
# =============================================================================

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # tfstate（インフラの現在状態を記録するファイル）をS3で管理する設定
  # 最初は backend "local" {} （ローカル管理）で始めてOK
  # チーム開発やCI/CDを使う場合はS3バックエンドに移行する
  #
  # backend "s3" {
  #   bucket = "your-tfstate-bucket-name"
  #   key    = "taskmanagement/terraform.tfstate"
  #   region = "ap-northeast-1"
  # }
}

# 現在の AWS アカウント情報を取得する（アカウントIDなどに使用）
data "aws_caller_identity" "current" {}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "TaskManagement"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# =============================================================================
# VPC（Virtual Private Cloud）
# =============================================================================
# VPC = AWS上に作る「自分専用の仮想ネットワーク空間」
# 他のAWSユーザーと完全に隔離されている
# cidr_block = このVPC内で使えるIPアドレスの範囲（10.0.0.0〜10.0.255.255）

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true   # VPC内でDNS名前解決を有効化
  enable_dns_hostnames = true   # EC2インスタンスにDNS名を付与

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# =============================================================================
# サブネット
# =============================================================================
# サブネット = VPCをさらに小さく分割したネットワーク
# 「パブリック」= インターネットから直接アクセス可能（ALBなどを置く）
# 「プライベート」= インターネットから直接アクセス不可（ECS・RDSを置く）
#
# 可用性のため、2つのAZ（アベイラビリティゾーン = データセンター）に分散させる

resource "aws_subnet" "public" {
  count             = length(var.public_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  # このサブネットに置いたリソースに自動でパブリックIPを付与
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet-${count.index + 1}"
    Type = "Public"
  }
}

resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${var.project_name}-private-subnet-${count.index + 1}"
    Type = "Private"
  }
}

# =============================================================================
# インターネットゲートウェイ（IGW）
# =============================================================================
# IGW = VPCとインターネットを繋ぐ「出入り口」
# これがないと、パブリックサブネットもインターネットに出られない

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# =============================================================================
# ルートテーブル
# =============================================================================
# ルートテーブル = ネットワークの「案内板」
# 「どのIPアドレス宛のパケットをどこに送るか」を定義する

# パブリックサブネット用：インターネット宛はIGWへ
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"            # すべてのIPアドレス宛
    gateway_id = aws_internet_gateway.main.id  # IGWへ送る
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# ルートテーブルとパブリックサブネットを紐付ける
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# プライベートサブネット用：デフォルトルートテーブルを使用（インターネット出口なし）
# ※ Phase 4以降でNAT Gatewayを追加してECSからのアウトバウンドを許可する

# =============================================================================
# セキュリティグループ
# =============================================================================
# セキュリティグループ = リソースへの「ファイアウォール」
# どのポート・どのIPからの通信を許可/拒否するかを定義する

# ALB（ロードバランサー）用セキュリティグループ
# インターネットからのHTTP/HTTPSを受け付ける
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "ALB security group - allows HTTP/HTTPS from internet"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

# ECS（コンテナ）用セキュリティグループ
# ALBからのトラフィックのみ受け付ける
resource "aws_security_group" "ecs" {
  name        = "${var.project_name}-ecs-sg"
  description = "ECS tasks security group - allows traffic from ALB only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Traffic from ALB (backend port)"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]  # ALB SGからのみ許可
  }

  ingress {
    description     = "Traffic from ALB (frontend port)"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-ecs-sg"
  }
}

# RDS（データベース）用セキュリティグループ
# ECSからのPostgreSQL接続のみ受け付ける
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "RDS security group - allows PostgreSQL from ECS only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from ECS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]  # ECS SGからのみ許可
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-rds-sg"
  }
}

# =============================================================================
# NAT Gateway（Phase 4 追加）
# =============================================================================
# NAT Gateway = プライベートサブネット内のリソースがインターネットへ出るための出口
#
# なぜ必要か?
#   ECS Fargate はプライベートサブネットで動く
#   コンテナ起動時に ECR からイメージをダウンロードする必要がある
#   → プライベートサブネットはインターネットに直接出られないので NAT Gateway が必要
#
# ※ NAT Gateway は約 $0.062/時間（≒ 約 $45/月）かかる
#    学習コスト削減のため、VPC エンドポイントで代替することも可能（後述）
#
# コスト削減の代替案:
#   aws_vpc_endpoint で ECR / CloudWatch / S3 へのプライベート通信を設定すると
#   NAT Gateway なしで ECS を起動できる（上級者向け。Phase 5以降で検討）

resource "aws_eip" "nat" {
  count  = length(var.public_subnet_cidrs)
  domain = "vpc"
  # EIP（Elastic IP）= 固定パブリック IP アドレス
  # NAT Gateway に割り当てる

  tags = {
    Name = "${var.project_name}-nat-eip-${count.index + 1}"
  }
}

resource "aws_nat_gateway" "main" {
  count         = length(var.public_subnet_cidrs)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  # NAT Gateway 自体はパブリックサブネットに置く（インターネットに出る出口のため）
  # プライベートサブネットのルートテーブルから NAT Gateway に向ける

  depends_on = [aws_internet_gateway.main]  # IGW が先に作られる必要がある

  tags = {
    Name = "${var.project_name}-nat-gw-${count.index + 1}"
  }
}

# プライベートサブネット用ルートテーブル（NAT Gateway 経由でインターネットへ）
resource "aws_route_table" "private" {
  count  = length(var.private_subnet_cidrs)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = {
    Name = "${var.project_name}-private-rt-${count.index + 1}"
  }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
