# =============================================================================
# 出力値（Outputs）
# =============================================================================
# outputs.tf = terraform apply 後に表示させたい値を定義するファイル

output "aws_region" {
  description = "使用しているAWSリージョン"
  value       = var.aws_region
}

output "vpc_id" {
  description = "作成したVPCのID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "パブリックサブネットのIDリスト"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "プライベートサブネットのIDリスト（Phase 2 の RDS 用）"
  value       = aws_subnet.private[*].id
}

# =============================================================================
# EC2 出力値
# =============================================================================

output "ec2_public_ip" {
  description = "EC2 の固定パブリック IP（Elastic IP）"
  value       = aws_eip.main.public_ip
}

output "ec2_instance_id" {
  description = "EC2 インスタンス ID"
  value       = aws_instance.main.id
}

output "ssh_command" {
  description = "EC2 への SSH 接続コマンド"
  value       = "ssh -i ~/.ssh/taskmanagement ec2-user@${aws_eip.main.public_ip}"
}

output "app_url" {
  description = "アプリへのアクセス URL（Nginx 経由）"
  value       = "http://${aws_eip.main.public_ip}"
}

output "health_check_url" {
  description = "ヘルスチェック URL"
  value       = "http://${aws_eip.main.public_ip}/health"
}

output "setup_log_command" {
  description = "EC2 セットアップログの確認コマンド（SSH ログイン後に実行）"
  value       = "sudo tail -f /var/log/user-data.log"
}
