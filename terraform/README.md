# Terraform インフラ構成

このディレクトリはTaskManagementアプリのAWSインフラをTerraformで管理します。

## ディレクトリ構成

```
terraform/
├── main.tf          # VPC・サブネット・セキュリティグループ（Phase 1）
├── rds.tf           # RDS（PostgreSQL）・サブネットグループ（Phase 2）
├── ecr.tf           # ECR リポジトリ（Phase 3）
├── variables.tf     # 変数定義
├── outputs.tf       # 出力値定義
├── terraform.tfvars # 変数の実際の値
└── README.md        # このファイル

scripts/
└── build-and-push.sh  # Docker イメージのビルド & ECR へのプッシュ（Phase 3）

backend/
├── Dockerfile         # マルチステージビルド（JDK → JRE）（Phase 3）
└── .dockerignore

frontend/
├── Dockerfile         # マルチステージビルド（Node → Nginx）（Phase 3）
├── nginx.conf         # SPA ルーティング・API プロキシ設定
└── .dockerignore
```

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

### Phase 3（現在）: ECR + Docker コンテナ化

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

### 次のフェーズ

| フェーズ | 内容 |
|---------|------|
| Phase 4 | ECS Fargate（コンテナ実行環境）構築 |
| Phase 5 | ALB（ロードバランサー）+ 外部公開 |

## 注意事項

- `terraform apply` を実行するとAWSにリソースが作成され、**課金が発生します**
- 学習・検証が終わったら `terraform destroy` でリソースを削除してください
- `*.tfstate` ファイルにはインフラの状態が記録されます。`.gitignore` で除外していますが、チーム開発ではS3バックエンドへの移行を検討してください
