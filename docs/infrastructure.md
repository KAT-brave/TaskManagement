# インフラ構成

## 構成図

```
インターネット
      │
      │ HTTP 80（全開放）
      │ HTTPS 443（全開放）
      │ SSH 22（自分の PC のみ）
      │ Spring Boot 8080（自分の PC のみ）
      ▼
┌─────────────────────────────────────────┐
│  EC2 t3.micro（Amazon Linux 2023）      │
│  パブリックサブネット（ap-northeast-1a） │
│                                         │
│  ├── Nginx（ポート 80）                 │
│  │     /api/* → localhost:8080 へ転送  │
│  │     それ以外 → 静的ファイル配信      │
│  │                                      │
│  ├── Spring Boot（ポート 8080）         │
│  │     Java 25 / Amazon Corretto        │
│  │                                      │
│  └── フロントエンド静的ファイル         │
│        /opt/taskmanagement/frontend/    │
└─────────────────────────────────────────┘
      │
      │ PostgreSQL 5432（EC2 からのみ・SSL 必須）
      ▼
┌─────────────────────────────────────────┐
│  RDS db.t3.micro（PostgreSQL 16）       │
│  プライベートサブネット（マルチ AZ）    │
└─────────────────────────────────────────┘
```

## AWS リソース

| リソース | 種別 | 備考 |
|---------|------|------|
| VPC | 10.0.0.0/16 | 東京リージョン（ap-northeast-1） |
| パブリックサブネット | 10.0.1.0/24 / 10.0.2.0/24 | 2AZ |
| プライベートサブネット | 10.0.10.0/24 / 10.0.11.0/24 | RDS 用・2AZ |
| EC2 | t3.micro | Amazon Linux 2023・無料枠 |
| Elastic IP | - | EC2 に固定パブリック IP を付与 |
| EBS | gp3 / 20GB | EC2 のルートボリューム・暗号化済み |
| RDS | db.t3.micro / PostgreSQL 16 | プライベートサブネット・暗号化済み |

## セキュリティグループ

### EC2

| ポート | 用途 | 許可元 |
|--------|------|--------|
| 22 | SSH | 開発者 PC のみ |
| 80 | HTTP（Nginx） | 全開放 |
| 443 | HTTPS（将来用） | 全開放 |
| 8080 | Spring Boot 直接接続 | 開発者 PC のみ |

### RDS

| ポート | 用途 | 許可元 |
|--------|------|--------|
| 5432 | PostgreSQL | EC2 セキュリティグループのみ |

## EC2 インストール済みソフトウェア

| ソフトウェア | バージョン | 用途 |
|------------|-----------|------|
| Java（Amazon Corretto） | 25 | Spring Boot 実行環境 |
| Node.js | 22 | フロントエンドビルド環境 |
| Nginx | 1.30 | リバースプロキシ・静的ファイル配信 |

## ディレクトリ構成（EC2 上）

```
/opt/taskmanagement/
├── app.jar          # Spring Boot の JAR ファイル
└── frontend/        # React のビルドファイル（dist/ の中身）
    ├── index.html
    └── assets/

/etc/systemd/system/taskmanagement.service  # Spring Boot サービス定義
/etc/nginx/conf.d/taskmanagement.conf       # Nginx 設定
/var/log/user-data.log                      # EC2 セットアップログ
```

## Terraform 構成

インフラは Terraform で管理しています。コードは [terraform/](../terraform/) を参照してください。

```
terraform/
├── main.tf          # VPC・サブネット・セキュリティグループ
├── ec2.tf           # EC2・Elastic IP・SSH キーペア
├── rds.tf           # RDS・サブネットグループ
├── variables.tf     # 変数定義
├── outputs.tf       # 出力値
└── terraform.tfvars # 設定値

scripts/
├── setup-ssh-key.sh # SSH キー作成（初回のみ）
├── start-ec2.sh     # EC2 起動スクリプト
└── stop-ec2.sh      # EC2 削除スクリプト
```

## 環境の起動・停止

```bash
# 起動（課金が発生します）
export TF_VAR_db_password="パスワード"
cd terraform && terraform apply

# 停止（課金が止まります）
cd terraform && terraform destroy
```

## デプロイ手順

### バックエンド

```bash
# ビルド
cd backend && ./mvnw package -DskipTests

# EC2 に転送
scp -i ~/.ssh/taskmanagement target/backend-0.0.1-SNAPSHOT.jar \
  ec2-user@<EC2のIP>:/opt/taskmanagement/app.jar

# EC2 上でサービス再起動
ssh -i ~/.ssh/taskmanagement ec2-user@<EC2のIP>
sudo systemctl restart taskmanagement
```

### フロントエンド

```bash
# ビルド
cd frontend && npm run build

# EC2 に転送
scp -i ~/.ssh/taskmanagement -r dist/* \
  ec2-user@<EC2のIP>:/opt/taskmanagement/frontend/

# Nginx をリロード
ssh -i ~/.ssh/taskmanagement ec2-user@<EC2のIP>
sudo systemctl reload nginx
```
