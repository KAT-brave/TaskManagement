# =============================================================================
# IAM ロール（ECS 用）
# =============================================================================
# IAM（Identity and Access Management）= AWSリソースへのアクセス権限管理
#
# ECS には 2 種類の IAM ロールが必要:
#
#   1. タスク実行ロール（Task Execution Role）
#      ECS エージェント（AWS の管理部分）が使うロール
#      - ECR からイメージをダウンロードする権限
#      - CloudWatch Logs にログを書き込む権限
#      - Secrets Manager からシークレットを取得する権限
#
#   2. タスクロール（Task Role）
#      コンテナの中で動くアプリが使うロール
#      - S3 にファイルをアップロードする権限（必要な場合）
#      - DynamoDB にアクセスする権限（必要な場合）
#      - 今回は最小限の設定

# =============================================================================
# タスク実行ロール（ECS エージェントが使うロール）
# =============================================================================

resource "aws_iam_role" "ecs_task_execution" {
  name        = "${var.project_name}-ecs-task-execution-role"
  description = "ECS タスク実行ロール: ECR pull・CloudWatch Logs 書き込み・Secrets Manager 読み取り"

  # 信頼ポリシー: このロールを誰が「引き受け」られるか
  # ECS タスクエージェントのみが AssumeRole できる
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# AWS 管理ポリシーをアタッチ（ECR pull + CloudWatch Logs 書き込み）
resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Secrets Manager からシークレットを取得する権限を追加
# DBパスワードなどを安全に渡すために使う
resource "aws_iam_policy" "ecs_secrets_access" {
  name        = "${var.project_name}-ecs-secrets-access"
  description = "ECS タスクが Secrets Manager のシークレットを読み取る権限"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameters",
          "ssm:GetParameter"
        ]
        Resource = [
          "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_secrets_access" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = aws_iam_policy.ecs_secrets_access.arn
}

# =============================================================================
# タスクロール（コンテナのアプリが使うロール）
# =============================================================================

resource "aws_iam_role" "ecs_task" {
  name        = "${var.project_name}-ecs-task-role"
  description = "ECS タスクロール: コンテナ内アプリの AWS 操作権限"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# ECS Exec（コンテナへのデバッグ接続）を有効にするポリシー
# `aws ecs execute-command` でコンテナのシェルに入れるようになる
resource "aws_iam_policy" "ecs_exec" {
  name        = "${var.project_name}-ecs-exec"
  description = "ECS Exec（コンテナへのデバッグ接続）を許可"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ssmmessages:CreateControlChannel",
        "ssmmessages:CreateDataChannel",
        "ssmmessages:OpenControlChannel",
        "ssmmessages:OpenDataChannel"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_exec" {
  role       = aws_iam_role.ecs_task.name
  policy_arn = aws_iam_policy.ecs_exec.arn
}
