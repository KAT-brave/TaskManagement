# =============================================================================
# ECR（Elastic Container Registry）
# =============================================================================
# ECR = AWS のコンテナイメージ置き場（Docker Hub の AWS 版）
#
# Docker Hub との違い:
#   - AWS IAM と統合されている（認証が AWS 認証情報で完結）
#   - VPC 内からのアクセスが速い（AWS 内部ネットワークを使う）
#   - プライベートリポジトリが無料（枠あり）
#
# このプロジェクトでは以下の2つのリポジトリを作成する:
#   - taskmanagement/backend  （Spring Boot）
#   - taskmanagement/frontend （React + Nginx）

# -----------------------------------------------------------------------------
# バックエンド用 ECR リポジトリ
# -----------------------------------------------------------------------------
resource "aws_ecr_repository" "backend" {
  name                 = "${var.project_name}/backend"
  image_tag_mutability = "MUTABLE"
  # MUTABLE = 同じタグ（例: latest）で上書き可能
  # IMMUTABLE = タグを上書き不可（本番でのタグ管理を厳密にしたい場合）

  image_scanning_configuration {
    scan_on_push = true
    # プッシュ時に脆弱性スキャンを実行する
    # CVE（既知の脆弱性）が含まれていないか自動チェックしてくれる
  }

  encryption_configuration {
    encryption_type = "AES256"  # イメージをAWS管理キーで暗号化
  }

  tags = {
    Name = "${var.project_name}-backend-ecr"
  }
}

# -----------------------------------------------------------------------------
# フロントエンド用 ECR リポジトリ
# -----------------------------------------------------------------------------
resource "aws_ecr_repository" "frontend" {
  name                 = "${var.project_name}/frontend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = "${var.project_name}-frontend-ecr"
  }
}

# -----------------------------------------------------------------------------
# ECR ライフサイクルポリシー（古いイメージの自動削除）
# -----------------------------------------------------------------------------
# ECR はイメージを保持し続けるとストレージコストがかかる
# ライフサイクルポリシーで古いイメージを自動削除する
#
# 無料枠: 500MB/月まで無料
# それ以上は $0.10/GB/月かかる

resource "aws_ecr_lifecycle_policy" "backend" {
  repository = aws_ecr_repository.backend.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "最新10件以外の untagged イメージを削除"
        selection = {
          tagStatus   = "untagged"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "最新30件を超えた tagged イメージを削除"
        selection = {
          tagStatus   = "tagged"
          tagPrefixList = ["v", "sha-"]
          countType   = "imageCountMoreThan"
          countNumber = 30
        }
        action = { type = "expire" }
      }
    ]
  })
}

resource "aws_ecr_lifecycle_policy" "frontend" {
  repository = aws_ecr_repository.frontend.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "最新10件以外の untagged イメージを削除"
        selection = {
          tagStatus   = "untagged"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "最新30件を超えた tagged イメージを削除"
        selection = {
          tagStatus   = "tagged"
          tagPrefixList = ["v", "sha-"]
          countType   = "imageCountMoreThan"
          countNumber = 30
        }
        action = { type = "expire" }
      }
    ]
  })
}
