# =============================================================================
# 出力値（Outputs）
# =============================================================================
# outputs.tf = terraform apply 後に表示させたい値を定義するファイル
# 他のTerraformモジュールからも参照できる
# 例: VPC IDをここで出力しておくと、Phase 2（RDS構築）で参照できる

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
