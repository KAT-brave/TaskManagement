# Terraform インフラ構成

このディレクトリはTaskManagementアプリのAWSインフラをTerraformで管理します。

## ディレクトリ構成

```
terraform/
├── main.tf          # VPC・サブネット・セキュリティグループ（Phase 1）
├── variables.tf     # 変数定義
├── outputs.tf       # 出力値定義
├── terraform.tfvars # 変数の実際の値
└── README.md        # このファイル
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

## AWSアーキテクチャ

### Phase 1（現在）: ネットワーク層

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

### 将来のフェーズ

| フェーズ | 内容 |
|---------|------|
| Phase 2 | RDS（PostgreSQL）構築 |
| Phase 3 | ECR（コンテナレジストリ）+ Dockerイメージのpush |
| Phase 4 | ECS Fargate（コンテナ実行環境）構築 |
| Phase 5 | ALB（ロードバランサー）+ 外部公開 |

## 注意事項

- `terraform apply` を実行するとAWSにリソースが作成され、**課金が発生します**
- 学習・検証が終わったら `terraform destroy` でリソースを削除してください
- `*.tfstate` ファイルにはインフラの状態が記録されます。`.gitignore` で除外していますが、チーム開発ではS3バックエンドへの移行を検討してください
