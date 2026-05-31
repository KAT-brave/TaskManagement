# =============================================================================
# ECS（Elastic Container Service）Fargate
# =============================================================================
# ECS = Docker コンテナを AWS 上で実行・管理するサービス
# Fargate = サーバーレスのコンテナ実行環境
#
# 「サーバーレス」の意味:
#   EC2（仮想サーバー）を自分で用意・管理しなくていい
#   コンテナが必要なときだけ起動し、CPU/メモリをリソース量に応じて課金される
#
# ECS の主な構成要素:
#
#   クラスター（Cluster）
#   └── コンテナを動かす「グループ」。論理的な区切り。
#
#   タスク定義（Task Definition）
#   └── 「どのイメージを・どのくらいのリソースで・どの環境変数で動かすか」のレシピ
#       Docker Compose の docker-compose.yml に相当する
#
#   サービス（Service）
#   └── タスクを「何個」「どこで」動かし続けるかを管理する
#       タスクが落ちたら自動で再起動してくれる
#       ALB との連携やローリングアップデートも管理する

# =============================================================================
# CloudWatch ロググループ
# =============================================================================
# ECS コンテナの stdout/stderr を CloudWatch Logs に送る
# アプリのログ（Spring Boot のログ、Nginx のアクセスログ）がここに集まる

resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/${var.project_name}/backend"
  retention_in_days = 30  # 30日でログを自動削除（コスト管理）

  tags = {
    Name = "${var.project_name}-backend-logs"
  }
}

resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/ecs/${var.project_name}/frontend"
  retention_in_days = 30

  tags = {
    Name = "${var.project_name}-frontend-logs"
  }
}

# =============================================================================
# ECS クラスター
# =============================================================================

resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
    # Container Insights = ECS の詳細メトリクスを CloudWatch に送る機能
    # CPU・メモリ・ネットワーク・タスク数などを監視できる
  }

  tags = {
    Name = "${var.project_name}-ecs-cluster"
  }
}

# =============================================================================
# タスク定義: バックエンド（Spring Boot）
# =============================================================================

resource "aws_ecs_task_definition" "backend" {
  family                   = "${var.project_name}-backend"
  requires_compatibilities = ["FARGATE"]   # Fargate モードを指定
  network_mode             = "awsvpc"      # Fargate は awsvpc のみ（各タスクに ENI が付く）
  cpu                      = var.backend_cpu     # タスク全体の CPU（256 = 0.25 vCPU）
  memory                   = var.backend_memory  # タスク全体のメモリ（MB）

  execution_role_arn = aws_iam_role.ecs_task_execution.arn  # ECR pull・ログ書き込み権限
  task_role_arn      = aws_iam_role.ecs_task.arn            # アプリが AWS を操作する権限

  container_definitions = jsonencode([
    {
      name  = "backend"
      image = "${aws_ecr_repository.backend.repository_url}:latest"
      # ※ 本番では :latest ではなく具体的なタグ（sha-xxxxx）を指定すること
      #    今回は学習用のためシンプルに latest を使う

      essential = true  # このコンテナが落ちたらタスク全体を停止する

      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]

      # =======================================================================
      # 環境変数
      # =======================================================================
      # Spring Boot に渡す設定値
      # ⚠️ 学習目的で db_password を環境変数に直接設定している
      #    本番では secrets ブロックを使い Secrets Manager から取得すること
      environment = [
        { name = "SPRING_PROFILES_ACTIVE",     value = "aws" },
        { name = "SPRING_DATASOURCE_URL",      value = "jdbc:postgresql://${aws_db_instance.main.endpoint}/${aws_db_instance.main.db_name}" },
        { name = "SPRING_DATASOURCE_USERNAME", value = var.db_username },
        { name = "SPRING_DATASOURCE_PASSWORD", value = var.db_password },
        { name = "JAVA_OPTS",                  value = "-Xms256m -Xmx512m -XX:+UseContainerSupport" }
        # -XX:+UseContainerSupport: コンテナのメモリ上限を JVM が正しく認識する
      ]

      # ログ設定: stdout/stderr を CloudWatch Logs に送る
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.backend.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      # ヘルスチェック（ECS レベル）
      # ALB のヘルスチェックとは別に ECS 自体もコンテナの状態を監視する
      healthCheck = {
        command     = ["CMD-SHELL", "wget -qO- http://localhost:8080/actuator/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60  # 起動後 60 秒はヘルスチェックを待つ（Spring Boot の起動時間）
      }
    }
  ])

  tags = {
    Name = "${var.project_name}-backend-task"
  }
}

# =============================================================================
# タスク定義: フロントエンド（React + Nginx）
# =============================================================================

resource "aws_ecs_task_definition" "frontend" {
  family                   = "${var.project_name}-frontend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.frontend_cpu
  memory                   = var.frontend_memory

  execution_role_arn = aws_iam_role.ecs_task_execution.arn
  task_role_arn      = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "frontend"
      image     = "${aws_ecr_repository.frontend.repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = 80
          protocol      = "tcp"
        }
      ]

      # Nginx は環境変数が不要（静的ファイルを配信するだけ）
      environment = []

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.frontend.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "wget -qO- http://localhost:80/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 10
      }
    }
  ])

  tags = {
    Name = "${var.project_name}-frontend-task"
  }
}

# =============================================================================
# ECS サービス: バックエンド
# =============================================================================
# サービス = 「このタスク定義を N 個動かし続けろ」という命令
# タスクが落ちたら自動再起動、スケーリング、ALB 連携を管理する

resource "aws_ecs_service" "backend" {
  name            = "${var.project_name}-backend-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = var.backend_desired_count  # 起動するタスク数
  launch_type     = "FARGATE"

  # ECS Exec を有効化（コンテナへのデバッグ接続用）
  enable_execute_command = true

  network_configuration {
    subnets          = aws_subnet.private[*].id  # プライベートサブネットで起動
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false  # プライベートサブネットなのでパブリック IP は不要
  }

  # ALB との連携
  load_balancer {
    target_group_arn = aws_lb_target_group.backend.arn
    container_name   = "backend"
    container_port   = 8080
  }

  # デプロイ設定（ローリングアップデート）
  deployment_circuit_breaker {
    enable   = true   # デプロイが失敗したら自動でロールバック
    rollback = true
  }

  deployment_minimum_healthy_percent = 50   # アップデート中も最低 50% のタスクを維持
  deployment_maximum_percent         = 200  # アップデート中は最大 200% まで起動可能

  depends_on = [
    aws_lb_listener.http,
    aws_iam_role_policy_attachment.ecs_task_execution_policy
  ]

  tags = {
    Name = "${var.project_name}-backend-service"
  }

  lifecycle {
    # デプロイのたびに Terraform が task_definition を更新しようとするのを防ぐ
    # CI/CD パイプラインから新しいイメージでデプロイする場合は ignore する
    ignore_changes = [task_definition]
  }
}

# =============================================================================
# ECS サービス: フロントエンド
# =============================================================================

resource "aws_ecs_service" "frontend" {
  name            = "${var.project_name}-frontend-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = var.frontend_desired_count
  launch_type     = "FARGATE"

  enable_execute_command = true

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend.arn
    container_name   = "frontend"
    container_port   = 80
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  depends_on = [
    aws_lb_listener.http,
    aws_iam_role_policy_attachment.ecs_task_execution_policy
  ]

  tags = {
    Name = "${var.project_name}-frontend-service"
  }

  lifecycle {
    ignore_changes = [task_definition]
  }
}
