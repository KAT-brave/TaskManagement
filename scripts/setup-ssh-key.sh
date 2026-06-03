#!/bin/bash
# =============================================================================
# SSH キーペアのセットアップ（terraform apply の前に一度だけ実行する）
# =============================================================================

set -e

KEY_PATH="$HOME/.ssh/taskmanagement"

if [ -f "$KEY_PATH" ]; then
  echo "SSH キーはすでに存在します: $KEY_PATH"
  echo "公開鍵の内容:"
  cat "${KEY_PATH}.pub"
  exit 0
fi

echo "SSH キーを作成します..."
ssh-keygen -t ed25519 -C "taskmanagement" -f "$KEY_PATH" -N ""

echo ""
echo "✅ SSH キーを作成しました"
echo "  秘密鍵: $KEY_PATH        （絶対に外部に公開しないこと）"
echo "  公開鍵: ${KEY_PATH}.pub  （Terraform が AWS に登録する）"
