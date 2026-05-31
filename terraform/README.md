# Terraform インフラ構成

このディレクトリはTaskManagementアプリのAWSインフラをTerraformで管理します。

## ディレクトリ構成

```
terraform/
├── main.tf          # VPC・サブネット・セキュリティグループ・NAT GW（Phase 1+4）
├── rds.tf           # RDS（PostgreSQL）・サブネットグループ（Phase 2）
├── ecr.tf           # ECR リポジトリ（Phase 3）
├── iam.tf           # ECS タスク実行ロール・タスクロール（Phase 4）
├── alb.tf           # ALB・ターゲットグループ・リスナー（Phase 4+5）
├── ecs.tf           # ECS クラスター・タスク定義・サービス（Phase 4）
├── acm.tf           # ACM 証明書（SSL/HTTPS）（Phase 5）
├── route53.tf       # Route 53 DNS レコード（Phase 5）
├── variables.tf     # 変数定義
├── outputs.tf       # 出力値定義
├── terraform.tfvars # 変数の実際の値
└── README.md        # このファイル

scripts/
├── start-infra.sh     # インフラ起動（apply + push + デプロイ）一括スクリプト
├── stop-infra.sh      # インフラ削除（課金停止）スクリプト
└── build-and-push.sh  # Docker イメージのビルド & ECR へのプッシュ（Phase 3）

backend/
├── Dockerfile         # マルチステージビルド（JDK → JRE）（Phase 3）
└── .dockerignore

frontend/
├── Dockerfile         # マルチステージビルド（Node → Nginx）（Phase 3）
├── nginx.conf         # SPA ルーティング・API プロキシ設定
└── .dockerignore
```

## ⚠️ コスト管理（重要）

### 現在のリソースと料金

| リソース | 料金 | 無料枠 |
|---|---|---|
| RDS（db.t3.micro） | 750時間/月まで無料 | ✅ 12ヶ月 |
| NAT Gateway × 2 | **約 $65〜90/月** | ❌ 対象外 |
| ALB | 約 $17〜20/月 | ❌ 対象外 |
| ECS Fargate | 約 $22〜27/月 | ❌ 対象外 |

> **24時間稼働させると月 $100〜130 かかります**

### 学習中の運用方法（必要な時だけ起動）

```bash
# 【起動】学習を始めるとき（約 20〜30 分）
export TF_VAR_db_password="your-password"
./scripts/start-infra.sh

# 【停止】学習が終わったとき（約 10〜15 分）
export TF_VAR_db_password="your-password"
./scripts/stop-infra.sh
```

### 課金の確認方法

```bash
# AWS のコスト確認
open https://ap-northeast-1.console.aws.amazon.com/billing/home#/bills

# 残っているリソースを確認
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Project,Values=TaskManagement \
  --region ap-northeast-1 \
  --query 'ResourceTagMappingList[].ResourceARN' \
  --output text
```

---

## 前提条件

### インストール

```bash
# AWS CLI
brew install awscli

# Terraform
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

### AWS認証設定

```bash
# IAMユーザーのアクセスキーを設定
aws configure

# 設定確認
aws sts get-caller-identity
```

## 使い方

```bash
# terraform/ ディレクトリに移動
cd terraform

# 初期化（初回のみ。プロバイダーをダウンロードする）
terraform init

# 変更内容のプレビュー（実際には何も変わらない）
terraform plan

# AWSにリソースを作成・変更する
terraform apply

# 作成したリソースをすべて削除する（課金停止のため）
terraform destroy
```

## Phase 2: RDS のデプロイ手順

### 1. DBパスワードを環境変数で設定する

```bash
# ⚠️ パスワードをファイルに書くと Git に残ってしまう
# 必ず環境変数で渡すこと

export TF_VAR_db_password="your-secure-password-here"
# 推奨: 大文字・小文字・数字・記号を含む16文字以上
```

### 2. プランを確認して適用する

```bash
cd terraform
terraform init   # 初回のみ

terraform plan   # 変更内容を確認（実際には何もしない）
# "Plan: 5 to add, 0 to change, 0 to destroy." と表示されればOK

terraform apply  # 実際にAWSにRDSを作成する（10〜15分かかる）
```

### 3. 接続情報を確認する

```bash
# terraform apply 完了後、出力値を確認する
terraform output

# Spring Boot の datasource.url をそのまま取得できる
terraform output spring_datasource_url
```

### 4. Spring Boot の設定を更新する

```bash
# ローカルから RDS に繋いで動作確認する場合
# application-aws.properties を使うようにプロファイルを切り替える

export SPRING_PROFILES_ACTIVE=aws
export SPRING_DATASOURCE_URL=$(cd terraform && terraform output -raw spring_datasource_url)
export SPRING_DATASOURCE_USERNAME=postgres
export SPRING_DATASOURCE_PASSWORD="your-secure-password-here"

cd backend && ./mvnw spring-boot:run
```

> ⚠️ **注意**: RDS はプライベートサブネットに配置されているため、
> ローカル PC から直接 RDS には接続できません。
> ローカルからの接続テストは SSH トンネル（踏み台サーバー）か
> VPN が必要です。ECS を構築（Phase 4）した後に動作確認するのが最もシンプルです。

## AWSアーキテクチャ

### Phase 1: ネットワーク層

```
ap-northeast-1（東京リージョン）
└── VPC (10.0.0.0/16)
    ├── パブリックサブネット-1 (10.0.1.0/24) - AZ: ap-northeast-1a
    ├── パブリックサブネット-2 (10.0.2.0/24) - AZ: ap-northeast-1c
    ├── プライベートサブネット-1 (10.0.10.0/24) - AZ: ap-northeast-1a
    ├── プライベートサブネット-2 (10.0.11.0/24) - AZ: ap-northeast-1c
    └── インターネットゲートウェイ
```

### セキュリティグループ

| 名前 | 目的 | インバウンド |
|------|------|------------|
| alb-sg | ALB（ロードバランサー） | 80, 443（インターネット全体） |
| ecs-sg | ECS（アプリコンテナ） | 8080, 80（ALBからのみ） |
| rds-sg | RDS（PostgreSQL） | 5432（ECSからのみ） |

### Phase 5（現在）: 独自ドメイン + HTTPS（ACM + Route 53）

```
インターネット
    ↓ https://example.com（HTTPS:443）
ALB（ACM 証明書で TLS 終端）
    ├── /api/* → バックエンド ECS
    └── それ以外 → フロントエンド ECS

http://example.com（HTTP:80）
    → 301 リダイレクト → https://example.com
```

## Phase 5: HTTPS 対応の手順

### ステップ 1: ドメインを取得する

**Route 53 で取得する場合（推奨・Terraform との相性が最高）**

```
AWS コンソール
  → Route 53
  → 「ドメインの登録」
  → ドメイン名を検索して購入（.com で約 $12〜15/年）
```

購入完了後、Route 53 にホストゾーンが自動作成されます。

**他のレジストラ（お名前.com など）で取得済みの場合**

```bash
# 1. Route 53 でホストゾーンを作成
aws route53 create-hosted-zone \
  --name example.com \
  --caller-reference $(date +%s)

# 2. 表示されたネームサーバー（NS）を元のレジストラに設定する
# → お名前.com の場合: ネームサーバーの変更 → カスタムネームサーバーに入力
```

### ステップ 2: terraform.tfvars にドメインを設定する

```hcl
# terraform/terraform.tfvars を編集
domain_name = "example.com"   # ← 取得したドメインに変更
```

### ステップ 3: terraform apply を実行する

```bash
export TF_VAR_db_password="your-secure-password"
cd terraform
terraform plan   # 変更内容を確認（ACM・Route 53 レコードが追加される）
terraform apply  # 実行（ACM の DNS 検証に 2〜5分かかる）
```

### ステップ 4: アクセスを確認する

```bash
# アプリの URL を確認
terraform output app_url
# → https://example.com

# ブラウザで開いて🔒マークを確認
```

### ネームサーバーの確認（他レジストラの場合）

```bash
# Route 53 のネームサーバーを確認（元のレジストラに設定する必要がある値）
terraform output route53_nameservers

# DNS が正しく設定されているか確認（変更後 24〜72 時間かかる場合がある）
dig NS example.com
```

---

### Phase 4: ECS Fargate + ALB

```
インターネット
    ↓ HTTP:80
ALB（パブリックサブネット × 2AZ）
    ├── /api/* → バックエンド ECS サービス（:8080）
    └── それ以外 → フロントエンド ECS サービス（:80）

ECS Fargate（プライベートサブネット）
├── backend タスク（Spring Boot / 0.5vCPU, 1GB）
└── frontend タスク（React+Nginx / 0.25vCPU, 512MB）
    ↓
RDS PostgreSQL（プライベートサブネット）

プライベートサブネット → NAT Gateway → ECR・CloudWatch
```

## Phase 4: ECS Fargate のデプロイ手順

### 1. イメージを ECR にプッシュしてから Terraform を実行する

```bash
# まずイメージをプッシュ（タスク定義が ECR のイメージを参照するため）
./scripts/build-and-push.sh

# Terraform で ECS・ALB・NAT GW を作成（15〜20分かかる）
export TF_VAR_db_password="your-secure-password"
cd terraform && terraform apply
```

### 2. デプロイ後にアクセス URL を確認する

```bash
terraform output alb_dns_name
# → http://taskmanagement-alb-xxxxxxxxx.ap-northeast-1.elb.amazonaws.com
```

### 3. ECS タスクの状態を確認する

```bash
# タスクが Running になっているか確認
aws ecs list-tasks \
  --cluster taskmanagement-cluster \
  --region ap-northeast-1

# タスクの詳細（起動失敗の場合はここで原因がわかる）
aws ecs describe-tasks \
  --cluster taskmanagement-cluster \
  --tasks <TASK_ARN> \
  --region ap-northeast-1
```

### 4. ログを確認する

```bash
# バックエンドのログ（CloudWatch Logs）
aws logs tail /ecs/taskmanagement/backend --follow --region ap-northeast-1

# フロントエンドのログ
aws logs tail /ecs/taskmanagement/frontend --follow --region ap-northeast-1
```

### 5. 新しいイメージを再デプロイする

```bash
# イメージをビルドして ECR にプッシュ
./scripts/build-and-push.sh

# ECS サービスを強制再デプロイ（新しいイメージを取得して起動）
terraform output deploy_command_backend | bash
terraform output deploy_command_frontend | bash
```

### 6. コンテナのシェルに入ってデバッグする（ECS Exec）

```bash
# ECS Exec を使ってコンテナ内でコマンドを実行する
aws ecs execute-command \
  --cluster taskmanagement-cluster \
  --task <TASK_ARN> \
  --container backend \
  --interactive \
  --command "/bin/sh" \
  --region ap-northeast-1
```

---

### Phase 3: ECR + Docker コンテナ化

```
ECR（Elastic Container Registry）
├── taskmanagement/backend   ← Spring Boot イメージ
└── taskmanagement/frontend  ← React + Nginx イメージ

backend/Dockerfile  →  マルチステージビルド（JDK21 → JRE21-alpine）
frontend/Dockerfile →  マルチステージビルド（Node22 → Nginx1.27-alpine）
```

## Phase 3: ECR + Docker のデプロイ手順

### 1. ECR リポジトリを作成する

```bash
cd terraform
terraform apply   # ecr.tf が追加されたので ECR リポジトリが作成される
```

### 2. Docker イメージをビルドして ECR にプッシュする

```bash
# プロジェクトルートから実行
./scripts/build-and-push.sh

# バックエンドだけプッシュしたい場合
./scripts/build-and-push.sh --backend-only

# バージョンタグを指定する場合
./scripts/build-and-push.sh --tag v1.0.0
```

### 3. ECR にイメージが届いたか確認する

```bash
# バックエンドのイメージ一覧
aws ecr describe-images \
  --repository-name taskmanagement/backend \
  --region ap-northeast-1

# フロントエンドのイメージ一覧
aws ecr describe-images \
  --repository-name taskmanagement/frontend \
  --region ap-northeast-1
```

### ローカルで Docker イメージを動作確認する

```bash
# バックエンドのみビルドしてローカルで起動
cd backend
docker build -t taskmanagement-backend:local .
docker run -p 8080:8080 \
  -e SPRING_PROFILES_ACTIVE=default \
  taskmanagement-backend:local

# フロントエンドのみビルドしてローカルで起動
cd frontend
docker build -t taskmanagement-frontend:local .
docker run -p 3000:80 taskmanagement-frontend:local
```

---

### Phase 2: RDS（PostgreSQL）

```
VPC
└── プライベートサブネット（2AZ）
    └── RDS PostgreSQL 16（db.t3.micro）
        ├── マルチAZスタンバイ（本番推奨）
        ├── 自動バックアップ（7日保持）
        └── Enhanced Monitoring（60秒間隔）
```

### インフラ構築完了

Phase 1〜5 ですべての基本インフラが整いました。

**今後の発展的なトピック**

| テーマ | 内容 |
|---------|------|
| CI/CD | GitHub Actions で push → ECR → ECS 自動デプロイ |
| スケーリング | ECS Auto Scaling でタスク数を自動調整 |
| コスト最適化 | NAT Gateway → VPC Endpoint に置き換え |
| セキュリティ強化 | WAF（Web Application Firewall）の追加 |
| 監視 | CloudWatch アラームで異常を Slack 通知 |

## 注意事項

- `terraform apply` を実行するとAWSにリソースが作成され、**課金が発生します**
- 学習・検証が終わったら `terraform destroy` でリソースを削除してください
- `*.tfstate` ファイルにはインフラの状態が記録されます。`.gitignore` で除外していますが、チーム開発ではS3バックエンドへの移行を検討してください
