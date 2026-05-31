# =============================================================================
# 出力値（Outputs）
# =============================================================================
# outputs.tf = terraform apply 後に表示させたい値を定義するファイル
# 他のTerraformモジュールからも参照できる
# 例: VPC IDをここで出力しておくと、Phase 2（RDS構築）で参照できる

output "aws_region" {
  description = "使用しているAWSリージョン"
  value       = var.aws_region
}

output "vpc_id" {
  description = "作成したVPCのID"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPCのCIDRブロック"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "パブリックサブネットのIDリスト"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "プライベートサブネットのIDリスト"
  value       = aws_subnet.private[*].id
}

output "internet_gateway_id" {
  description = "インターネットゲートウェイのID"
  value       = aws_internet_gateway.main.id
}

output "alb_security_group_id" {
  description = "ALB用セキュリティグループのID"
  value       = aws_security_group.alb.id
}

output "ecs_security_group_id" {
  description = "ECS用セキュリティグループのID"
  value       = aws_security_group.ecs.id
}

output "rds_security_group_id" {
  description = "RDS用セキュリティグループのID"
  value       = aws_security_group.rds.id
}

# =============================================================================
# RDS 出力値（Phase 2）
# =============================================================================

output "rds_endpoint" {
  description = "RDSのエンドポイント（Spring Bootの接続先URLに使用）"
  value       = aws_db_instance.main.endpoint
  # 例: taskmanagement-db.xxxxxxxxxxxx.ap-northeast-1.rds.amazonaws.com:5432
}

output "rds_hostname" {
  description = "RDSのホスト名（ポート番号なし）"
  value       = aws_db_instance.main.address
}

output "rds_port" {
  description = "RDSのポート番号"
  value       = aws_db_instance.main.port
}

output "rds_db_name" {
  description = "RDSのデータベース名"
  value       = aws_db_instance.main.db_name
}

output "rds_username" {
  description = "RDSの接続ユーザー名"
  value       = aws_db_instance.main.username
}

output "spring_datasource_url" {
  description = "Spring Boot の spring.datasource.url に設定する値"
  value       = "jdbc:postgresql://${aws_db_instance.main.endpoint}/${aws_db_instance.main.db_name}"
  # terraform apply 後、この値をそのまま application.properties にコピーできる
}

# =============================================================================
# ECR 出力値（Phase 3）
# =============================================================================

output "ecr_backend_repository_url" {
  description = "バックエンド ECR リポジトリの URL（docker push に使用）"
  value       = aws_ecr_repository.backend.repository_url
  # 例: 123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/taskmanagement/backend
}

output "ecr_frontend_repository_url" {
  description = "フロントエンド ECR リポジトリの URL（docker push に使用）"
  value       = aws_ecr_repository.frontend.repository_url
}

output "ecr_registry_url" {
  description = "ECR レジストリの URL（docker login に使用）"
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}

# =============================================================================
# ALB / ECS 出力値（Phase 4）
# =============================================================================

output "alb_dns_name" {
  description = "ALB の DNS 名（ブラウザでアクセスする URL）"
  value       = "http://${aws_lb.main.dns_name}"
  # terraform apply 後、この URL でアプリにアクセスできる
  # 例: http://taskmanagement-alb-xxxxxxxxx.ap-northeast-1.elb.amazonaws.com
}

output "ecs_cluster_name" {
  description = "ECS クラスター名"
  value       = aws_ecs_cluster.main.name
}

output "ecs_backend_service_name" {
  description = "バックエンド ECS サービス名"
  value       = aws_ecs_service.backend.name
}

output "ecs_frontend_service_name" {
  description = "フロントエンド ECS サービス名"
  value       = aws_ecs_service.frontend.name
}

output "deploy_command_backend" {
  description = "バックエンドの新しいイメージでデプロイするコマンド"
  value       = "aws ecs update-service --cluster ${aws_ecs_cluster.main.name} --service ${aws_ecs_service.backend.name} --force-new-deployment --region ${var.aws_region}"
}

output "deploy_command_frontend" {
  description = "フロントエンドの新しいイメージでデプロイするコマンド"
  value       = "aws ecs update-service --cluster ${aws_ecs_cluster.main.name} --service ${aws_ecs_service.frontend.name} --force-new-deployment --region ${var.aws_region}"
}
