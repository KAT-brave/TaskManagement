# =============================================================================
# ACM（AWS Certificate Manager）
# =============================================================================
# ACM = SSL/TLS 証明書を無料で発行・管理する AWS サービス
#
# SSL/TLS 証明書とは？
#   HTTPS（暗号化通信）を実現するために必要な「身元証明書」
#   「このサーバーは本当に example.com です」を証明する
#   ブラウザのアドレスバーに🔒マークが表示されるようになる
#
# ACM のメリット:
#   - 無料（Let's Encrypt と同様）
#   - 自動更新（手動での更新作業が不要）
#   - ALB・CloudFront と簡単に統合できる
#
# DNS 検証とは？
#   「このドメインの所有者であることを Route 53 の DNS レコードで証明する」方法
#   Terraform が自動で CNAME レコードを作成して検証を完了させる
#
# ⚠️ ALB に使う ACM 証明書は us-east-1 ではなく ALB と同じリージョンに作る
#    （CloudFront 用の証明書は us-east-1 が必要だが今回は ALB なので ap-northeast-1）

resource "aws_acm_certificate" "main" {
  count = var.domain_name != "" ? 1 : 0  # domain_name が設定された場合のみ実行

  domain_name = var.domain_name                  # 主ドメイン: example.com
  subject_alternative_names = [
    "www.${var.domain_name}"                     # サブジェクト代替名: www.example.com
    # 1枚の証明書で複数のドメインをカバーできる
  ]

  validation_method = "DNS"
  # DNS 検証 = Route 53 に CNAME レコードを追加してドメイン所有を証明する
  # EMAIL 検証 という方法もあるが、DNS 検証の方が自動化しやすい

  lifecycle {
    # 新しい証明書を作ってから古いものを削除する
    # これにより証明書の切り替え時にダウンタイムが発生しない
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-acm-cert"
  }
}

# =============================================================================
# DNS 検証レコード（Route 53 に CNAME を追加）
# =============================================================================
# ACM が「このドメインの所有者ですか？」と聞いてくる
# Route 53 に CNAME レコードを追加することで「はい、私が所有者です」と答える
# Terraform がこれを自動で行う

resource "aws_route53_record" "acm_validation" {
  # domain_name が設定されていて、かつ証明書の検証レコードが存在する場合のみ作成
  for_each = var.domain_name != "" ? {
    for dvo in aws_acm_certificate.main[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60  # 60秒（検証完了後はもっと長くてもいい）
}

# ACM 証明書の検証が完了するのを待つ
# 証明書の状態が「発行済み」になるまで Terraform が待機する（数分かかる）
resource "aws_acm_certificate_validation" "main" {
  count = var.domain_name != "" ? 1 : 0

  certificate_arn         = aws_acm_certificate.main[0].arn
  validation_record_fqdns = [for record in aws_route53_record.acm_validation : record.fqdn]
}
