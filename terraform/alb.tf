# =============================================================================
# ALB（Application Load Balancer）
# =============================================================================
# ALB = アプリケーション層（HTTP/HTTPS）のロードバランサー
#
# 役割:
#   インターネット → ALB → ECS（フロントエンド or バックエンド）
#
# ALB が必要な理由:
#   - ECS タスクは起動・停止のたびに IP アドレスが変わる
#   - ALB が「今動いている ECS タスク」に自動で振り分けてくれる
#   - ヘルスチェックで異常なタスクを自動で除外する
#   - 複数 AZ に分散させて可用性を高める
#
# このプロジェクトの構成:
#   80番ポート（HTTP）でリクエストを受け取り
#   ├── /api/* → バックエンド（Spring Boot:8080）へ転送
#   └── それ以外 → フロントエンド（Nginx:80）へ転送

# =============================================================================
# ALB 本体
# =============================================================================

resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false  # false = インターネット向け（外部 ALB）
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id  # パブリックサブネット（2AZ）に配置

  enable_deletion_protection = false  # 学習中は誤削除を許容（本番は true に）

  # アクセスログを S3 に保存する設定（今回は無効）
  # access_logs {
  #   bucket  = "your-log-bucket"
  #   prefix  = "alb"
  #   enabled = true
  # }

  tags = {
    Name = "${var.project_name}-alb"
  }
}

# =============================================================================
# ターゲットグループ
# =============================================================================
# ターゲットグループ = ALB がリクエストを転送する先のグループ
# ECS タスクをここに登録し、ヘルスチェックで生死を監視する

# フロントエンド用ターゲットグループ
resource "aws_lb_target_group" "frontend" {
  name        = "${var.project_name}-frontend-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"  # ECS Fargate は "ip" を指定する（EC2 の場合は "instance"）

  health_check {
    enabled             = true
    path                = "/health"  # nginx.conf で定義したヘルスチェックエンドポイント
    healthy_threshold   = 2          # 2回連続で成功したら「正常」とみなす
    unhealthy_threshold = 3          # 3回連続で失敗したら「異常」とみなす
    timeout             = 5          # タイムアウト（秒）
    interval            = 30         # チェック間隔（秒）
    matcher             = "200"      # HTTP 200 を正常とみなす
  }

  # ECS サービスのローリングアップデート時の設定
  deregistration_delay = 30  # タスク削除前に 30 秒待つ（処理中リクエストを完結させる）

  tags = {
    Name = "${var.project_name}-frontend-tg"
  }
}

# バックエンド用ターゲットグループ
resource "aws_lb_target_group" "backend" {
  name        = "${var.project_name}-backend-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = "/actuator/health"  # Spring Boot Actuator のヘルスチェック
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name = "${var.project_name}-backend-tg"
  }
}

# =============================================================================
# リスナー（Listener）
# =============================================================================
# リスナー = ALB が「どのポートで待ち受けて、どのルールで振り分けるか」を定義する

# =============================================================================
# HTTP リスナー（:80）
# =============================================================================
# domain_name が設定されている場合: HTTP → HTTPS にリダイレクト
# domain_name が未設定の場合: HTTP のままフロントエンドに転送（Phase 1〜4 の動作）

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  dynamic "default_action" {
    # domain_name が設定されている場合は HTTPS リダイレクト
    for_each = var.domain_name != "" ? [1] : []
    content {
      type = "redirect"
      redirect {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"  # 恒久的なリダイレクト（ブラウザがキャッシュする）
      }
    }
  }

  dynamic "default_action" {
    # domain_name が未設定の場合はフロントエンドに転送（HTTP のまま）
    for_each = var.domain_name == "" ? [1] : []
    content {
      type             = "forward"
      target_group_arn = aws_lb_target_group.frontend.arn
    }
  }
}

# =============================================================================
# HTTPS リスナー（:443）
# =============================================================================
# domain_name が設定されている場合のみ作成
# ACM 証明書の検証完了を待ってから作成する

resource "aws_lb_listener" "https" {
  count = var.domain_name != "" ? 1 : 0

  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  # TLS 1.3 対応の最新ポリシー（TLS 1.0/1.1 などの古い暗号化を無効化）
  certificate_arn   = aws_acm_certificate_validation.main[0].certificate_arn

  # デフォルトアクション: フロントエンドに転送
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

# =============================================================================
# リスナールール: /api/* をバックエンドへ転送
# =============================================================================

# HTTP リスナー用（domain_name 未設定時）
resource "aws_lb_listener_rule" "api_http" {
  count        = var.domain_name == "" ? 1 : 0
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}

# HTTPS リスナー用（domain_name 設定時）
resource "aws_lb_listener_rule" "api_https" {
  count        = var.domain_name != "" ? 1 : 0
  listener_arn = aws_lb_listener.https[0].arn
  priority     = 10

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}
