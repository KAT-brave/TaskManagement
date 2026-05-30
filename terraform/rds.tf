# =============================================================================
# RDS（Relational Database Service）- PostgreSQL
# =============================================================================
# RDS = AWSのマネージドDBサービス
# 「マネージド」= OSのアップデート・バックアップ・フェイルオーバーをAWSが自動でやってくれる
# 自分でEC2にPostgreSQLをインストールするより運用コストが大幅に下がる

# -----------------------------------------------------------------------------
# DB サブネットグループ
# -----------------------------------------------------------------------------
# RDSを配置するサブネットのグループ
# 可用性のため、最低2つの異なるAZのサブネットが必要
# RDSはプライベートサブネットに配置する（インターネットから直接アクセスさせない）

resource "aws_db_subnet_group" "main" {
  name        = "${var.project_name}-db-subnet-group"
  description = "RDS subnet group for ${var.project_name}"
  subnet_ids  = aws_subnet.private[*].id  # Phase 1で作ったプライベートサブネット

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

# -----------------------------------------------------------------------------
# DB パラメータグループ
# -----------------------------------------------------------------------------
# PostgreSQLの動作設定をカスタマイズするグループ
# デフォルト値から変更したいパラメータだけを指定する

resource "aws_db_parameter_group" "main" {
  name        = "${var.project_name}-db-params"
  family      = "postgres16"  # PostgreSQL 16系
  description = "Parameter group for ${var.project_name} PostgreSQL"

  # ログ設定：実行されたSQLをCloudWatch Logsに記録する
  parameter {
    name  = "log_statement"
    value = "all"  # すべてのSQLを記録（本番では "ddl" や "mod" に変更推奨）
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"  # 1秒以上かかったクエリを記録（ミリ秒単位）
  }

  tags = {
    Name = "${var.project_name}-db-params"
  }
}

# -----------------------------------------------------------------------------
# RDS インスタンス
# -----------------------------------------------------------------------------

resource "aws_db_instance" "main" {
  # --- 識別子・エンジン設定 ---
  identifier     = "${var.project_name}-db"
  engine         = "postgres"
  engine_version = "16.3"  # PostgreSQL のバージョン

  # --- インスタンスサイズ ---
  # db.t3.micro = 最小構成（vCPU 2, メモリ 1GB）
  # 無料利用枠対象。本番では db.t3.small 以上を推奨
  instance_class = var.db_instance_class

  # --- ストレージ ---
  allocated_storage     = var.db_allocated_storage  # 初期容量 (GB)
  max_allocated_storage = 100                        # 自動スケールの上限 (GB)
  storage_type          = "gp3"                      # 汎用SSD（gp3は gp2より安くて速い）
  storage_encrypted     = true                       # 保存データを暗号化

  # --- DB設定 ---
  db_name  = var.db_name      # データベース名
  username = var.db_username  # 管理者ユーザー名
  password = var.db_password  # ⚠️ 実際の値は terraform.tfvars に書かずに後述の方法で渡す

  # --- ネットワーク ---
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]  # Phase 1で作ったSG
  publicly_accessible    = false  # パブリックサブネットからアクセス不可

  # --- パラメータグループ ---
  parameter_group_name = aws_db_parameter_group.main.name

  # --- バックアップ設定 ---
  backup_retention_period = var.db_backup_retention_days  # バックアップを保持する日数
  backup_window           = "03:00-04:00"                 # バックアップ実行時間帯（UTC）= 日本時間 12:00-13:00
  maintenance_window      = "Mon:04:00-Mon:05:00"         # メンテナンス時間帯（UTC）

  # --- 削除保護 ---
  # trueにするとAWSコンソール・CLIどちらからも誤削除を防げる
  # 学習中は false にしておき、本番移行時に true に変更する
  deletion_protection = var.db_deletion_protection

  # terraform destroy を実行したときにスナップショットを作成するか
  # 学習中は skip_final_snapshot = true にしてすぐ削除できるようにする
  skip_final_snapshot       = var.db_skip_final_snapshot
  final_snapshot_identifier = var.db_skip_final_snapshot ? null : "${var.project_name}-db-final-snapshot"

  # --- モニタリング ---
  monitoring_interval = 60  # Enhanced Monitoring の間隔（秒）。0で無効
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn

  # --- ログ出力 ---
  # CloudWatch Logsにpostgresqlのログを出力する
  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = {
    Name = "${var.project_name}-db"
  }
}

# -----------------------------------------------------------------------------
# RDS Enhanced Monitoring 用 IAM ロール
# -----------------------------------------------------------------------------
# Enhanced Monitoring = OSレベルのメトリクス（CPU・メモリ・ディスクI/O）を60秒間隔で取得する機能
# RDSがCloudWatchにメトリクスを書き込む権限が必要

resource "aws_iam_role" "rds_monitoring" {
  name = "${var.project_name}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "monitoring.rds.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
