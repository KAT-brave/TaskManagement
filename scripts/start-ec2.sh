#!/bin/bash
# =============================================================================
# EC2 インフラの起動（terraform apply）
# =============================================================================
# ⚠️  課金が発生します:
#   - EC2 t3.micro: 無料枠内（750時間/月）
#   - Elastic IP: EC2 に関連付け中は無料
#   - EBS 20GB: 無料枠内（30GB/月）
#
# 使い方:
#   ./scripts/start-ec2.sh
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform"

echo "======================================"
echo "  EC2 インフラ起動"
echo "======================================"
echo ""
echo "⚠️  以下のAWSリソースを作成します（課金対象）:"
echo "  - EC2 t3.micro（無料枠: 750時間/月まで）"
echo "  - Elastic IP（EC2稼働中は無料）"
echo "  - EBS 20GB（無料枠: 30GBまで）"
echo "  - VPC・サブネット・SG（無料）"
echo ""

# SSH キーの確認
if [ ! -f "$HOME/.ssh/taskmanagement.pub" ]; then
  echo "❌ SSH 公開鍵が見つかりません: ~/.ssh/taskmanagement.pub"
  echo "   先に以下を実行してください:"
  echo "   ./scripts/setup-ssh-key.sh"
  exit 1
fi

read -p "続行しますか？ (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
  echo "中止しました"
  exit 0
fi

echo ""
echo ">>> terraform apply を実行します..."
cd "$TERRAFORM_DIR"
terraform apply

echo ""
echo "======================================"
echo "✅ EC2 インフラの起動が完了しました！"
echo "======================================"
echo ""
echo "接続情報:"
terraform output ssh_command
echo ""
echo "アプリ URL:"
terraform output app_url
echo ""
echo "⚠️  EC2 のセットアップ（Java・Nginx のインストール）に"
echo "   約 2〜3 分かかります。"
echo "   以下でログを確認できます:"
echo "   $(terraform output -raw ssh_command) 'sudo tail -f /var/log/user-data.log'"
