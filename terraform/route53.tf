# =============================================================================
# Route 53（DNS サービス）
# =============================================================================
# Route 53 = AWS のドメイン・DNS 管理サービス
#
# DNS（Domain Name System）とは？
#   「ドメイン名」と「IP アドレス」を対応付けるシステム
#   例: taskmanagement.example.com → ALB の IP アドレス
#
# ホストゾーン（Hosted Zone）とは？
#   1つのドメイン（例: example.com）に対応する DNS レコードの集まり
#   「example.com のことは全部このホストゾーンで管理する」という設定
#
# =============================================================================
# 使い方（ドメインを取得してから実施）
# =============================================================================
#
# 【ステップ 1】ドメインを取得する
#   Route 53 でドメインを購入する場合:
#     AWS コンソール → Route 53 → ドメインの登録 → ドメインを検索して購入
#     購入後、ホストゾーンが自動で作成される
#
#   他のレジストラ（お名前.com など）で取得している場合:
#     Route 53 でホストゾーンを作成 → 表示される NS レコードを
#     元のレジストラの DNS 設定に登録する
#
# 【ステップ 2】terraform.tfvars に domain_name を設定する
#   domain_name = "example.com"
#
# 【ステップ 3】terraform apply を実行する
#
# =============================================================================

# ホストゾーンをデータソースとして取得
# 「既存のホストゾーンを Terraform から参照する」設定
# ドメインを Route 53 で購入するとホストゾーンが自動で作成される
data "aws_route53_zone" "main" {
  count = var.domain_name != "" ? 1 : 0  # domain_name が設定された場合のみ実行

  name         = var.domain_name
  private_zone = false  # パブリックホストゾーン（インターネットからアクセス可能）
}

# =============================================================================
# DNS レコード
# =============================================================================

# ALB を指す A レコード（エイリアス）
# 例: taskmanagement.example.com → ALB の DNS 名
resource "aws_route53_record" "app" {
  count = var.domain_name != "" ? 1 : 0

  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = var.domain_name       # ルートドメイン（example.com）
  type    = "A"

  # エイリアスレコード = Route 53 特有の仕組み
  # ALB のように IP が変動するリソースには CNAME ではなくエイリアスを使う
  # エイリアスは CNAME と違い、ルートドメイン（@）にも使える
  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true  # ALB が不健全な場合は DNS 応答しない
  }
}

# www サブドメインも同じ ALB に向ける
# 例: www.taskmanagement.example.com → ALB
resource "aws_route53_record" "app_www" {
  count = var.domain_name != "" ? 1 : 0

  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}
