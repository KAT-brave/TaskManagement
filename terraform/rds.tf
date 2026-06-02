# =============================================================================
# RDS（Relational Database Service）- PostgreSQL
# =============================================================================
# RDS = AWS のマネージド DB サービス
# マネージド = OS のアップデート・バックアップ・フェイルオーバーを AWS が自動でやってくれる

# =============================================================================
# DB サブネットグループ
# =============================================================================
# RDS を配置するサブネットのグループ
# 可用性のため、最低2つの異なる AZ のサブネットが必要

resource "aws_db_subnet_group" "main" {
  name        = "${var.project_name}-db-subnet-group"
  description = "RDS subnet group for ${var.project_name}"
  subnet_ids  = aws_subnet.private[*].id

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

# =============================================================================
# DB パラメータグループ
# =============================================================================
# PostgreSQL の動作設定をカスタマイズするグループ

resource "aws_db_parameter_group" "main" {
  name        = "${var.project_name}-db-params"
  family      = "postgres16"
  description = "Parameter group for ${var.project_name} PostgreSQL"

  tags = {
    Name = "${var.project_name}-db-params"
  }
}

# =============================================================================
# RDS インスタンス
# =============================================================================

resource "aws_db_instance" "main" {
  identifier     = "${var.project_name}-db"
  engine         = "postgres"
  engine_version = "16.3"

  instance_class        = var.db_instance_class      # db.t3.micro（無料枠）
  allocated_storage     = var.db_allocated_storage   # 20GB
  max_allocated_storage = 20                         # 自動スケール上限（無料枠内に抑える）
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]  # EC2 からのみ接続可
  publicly_accessible    = false                         # インターネットから直接アクセス不可

  parameter_group_name = aws_db_parameter_group.main.name

  backup_retention_period = var.db_backup_retention_days
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  deletion_protection       = var.db_deletion_protection
  skip_final_snapshot       = var.db_skip_final_snapshot
  final_snapshot_identifier = var.db_skip_final_snapshot ? null : "${var.project_name}-db-final-snapshot"

  tags = {
    Name = "${var.project_name}-db"
  }
}
