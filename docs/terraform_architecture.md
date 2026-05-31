# Terraform プロジェクト構成

## 目次

1. [プロジェクト全体の構成](#1-プロジェクト全体の構成)
2. [AWSアーキテクチャ図](#2-awsアーキテクチャ図)
3. [Terraform ファイルの役割一覧](#3-terraform-ファイルの役割一覧)
4. [AWSリソース一覧](#4-awsリソース一覧)
5. [変数・出力値](#5-変数出力値)
6. [運用スクリプト](#6-運用スクリプト)
7. [デプロイフロー](#7-デプロイフロー)
8. [コスト概算](#8-コスト概算)

---

## 1. プロジェクト全体の構成

```
TaskManagement/
│
├── terraform/                    # インフラ定義（IaC）
│   ├── main.tf                   # VPC・ネットワーク・セキュリティグループ・NAT Gateway
│   ├── rds.tf                    # RDS（PostgreSQL）データベース
│   ├── ecr.tf                    # ECR（コンテナイメージ置き場）
│   ├── iam.tf                    # IAM ロール・ポリシー
│   ├── alb.tf                    # ALB（ロードバランサー）
│   ├── ecs.tf                    # ECS Fargate（コンテナ実行環境）
│   ├── acm.tf                    # ACM（SSL/TLS 証明書）※ドメイン設定時のみ有効
│   ├── route53.tf                # Route 53（DNS）※ドメイン設定時のみ有効
│   ├── variables.tf              # 変数の型・説明・デフォルト値を定義
│   ├── outputs.tf                # terraform apply 後に表示される出力値
│   ├── terraform.tfvars          # 変数の実際の値（環境設定ファイル）
│   └── README.md                 # Terraform の使い方・手順書
│
├── scripts/                      # 運用自動化スクリプト
│   ├── start-infra.sh            # インフラ起動（apply + push + デプロイ一括）
│   ├── stop-infra.sh             # インフラ削除（課金停止）
│   └── build-and-push.sh        # Docker ビルド & ECR プッシュ
│
├── backend/                      # Spring Boot アプリケーション
│   ├── Dockerfile                # マルチステージビルド（JDK → JRE）
│   ├── .dockerignore
│   └── src/main/resources/
│       ├── application.properties          # ローカル開発用設定
│       └── application-aws.properties      # AWS 環境用設定（プロファイル切替）
│
└── frontend/                     # React アプリケーション
    ├── Dockerfile                # マルチステージビルド（Node → Nginx）
    ├── nginx.conf                # SPA ルーティング・API プロキシ設定
    └── .dockerignore
```

---

## 2. AWSアーキテクチャ図

```
┌─────────────────────────────────────────────────────────────────┐
│                        インターネット                             │
└──────────────────────────┬──────────────────────────────────────┘
                           │ HTTP:80 / HTTPS:443
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  Route 53（DNS）                                                 │
│  example.com → ALB の DNS 名                                    │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  ACM（SSL/TLS 証明書）                                           │
│  example.com の HTTPS 通信を暗号化                               │
└──────────────────────────┬──────────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────────┐
│               VPC（10.0.0.0/16）                                 │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  パブリックサブネット（インターネットから到達可能）          │    │
│  │                                                           │    │
│  │  ┌──────────────────────────────────────────────────┐   │    │
│  │  │  ALB（Application Load Balancer）               │   │    │
│  │  │  ┌─────────────────────────────────────────┐   │   │    │
│  │  │  │ HTTP:80 リスナー                         │   │   │    │
│  │  │  │  → HTTPS へ 301 リダイレクト             │   │   │    │
│  │  │  ├─────────────────────────────────────────┤   │   │    │
│  │  │  │ HTTPS:443 リスナー                       │   │   │    │
│  │  │  │  /api/* → バックエンド TG               │   │   │    │
│  │  │  │  それ以外 → フロントエンド TG            │   │   │    │
│  │  │  └─────────────────────────────────────────┘   │   │    │
│  │  └──────────────────────────────────────────────────┘   │    │
│  │                                                           │    │
│  │  ┌──────────┐  ┌──────────┐                             │    │
│  │  │NAT GW #1 │  │NAT GW #2 │  ← ECS → インターネットの出口│    │
│  │  │  AZ: 1a  │  │  AZ: 1c  │                             │    │
│  │  └──────────┘  └──────────┘                             │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  プライベートサブネット（インターネットから直接到達不可）    │    │
│  │                                                           │    │
│  │  ┌──────────────────┐  ┌──────────────────┐            │    │
│  │  │  ECS Fargate     │  │  ECS Fargate     │            │    │
│  │  │  AZ: 1a          │  │  AZ: 1c          │            │    │
│  │  │                  │  │                  │            │    │
│  │  │ ┌─────────────┐ │  │ ┌─────────────┐ │            │    │
│  │  │ │  backend    │ │  │ │  frontend   │ │            │    │
│  │  │ │ Spring Boot │ │  │ │ React+Nginx │ │            │    │
│  │  │ │ :8080       │ │  │ │ :80         │ │            │    │
│  │  │ └─────────────┘ │  │ └─────────────┘ │            │    │
│  │  └──────────────────┘  └──────────────────┘            │    │
│  │                                                           │    │
│  │  ┌──────────────────────────────────────────────┐       │    │
│  │  │  RDS（PostgreSQL 16）                        │       │    │
│  │  │  db.t3.micro / 20GB / 自動バックアップ 7日   │       │    │
│  │  └──────────────────────────────────────────────┘       │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘

外部サービス（AWS マネージド）
┌──────────────────────────────────────────────────────────────────┐
│  ECR（コンテナイメージ保管）                                       │
│  ├── taskmanagement/backend（Spring Boot イメージ）               │
│  └── taskmanagement/frontend（React + Nginx イメージ）            │
│                                                                    │
│  CloudWatch Logs（アプリログ保管）                                 │
│  ├── /ecs/taskmanagement/backend                                  │
│  └── /ecs/taskmanagement/frontend                                 │
└──────────────────────────────────────────────────────────────────┘
```

---

## 3. Terraform ファイルの役割一覧

### main.tf — ネットワーク基盤

| リソース | 内容 |
|---|---|
| `aws_vpc` | VPC（仮想ネットワーク空間） |
| `aws_subnet` public × 2 | パブリックサブネット（AZ: 1a・1c）ALB・NAT GW を配置 |
| `aws_subnet` private × 2 | プライベートサブネット（AZ: 1a・1c）ECS・RDS を配置 |
| `aws_internet_gateway` | VPC とインターネットをつなぐ出入り口 |
| `aws_route_table` public | パブリックサブネット用ルートテーブル（IGW 経由） |
| `aws_route_table` private × 2 | プライベートサブネット用（NAT GW 経由） |
| `aws_eip` × 2 | NAT GW 用の固定 IP アドレス |
| `aws_nat_gateway` × 2 | プライベートサブネットからの外部通信出口 |
| `aws_security_group` alb | ALB 用 SG（80・443 を全開放） |
| `aws_security_group` ecs | ECS 用 SG（ALB からの通信のみ許可） |
| `aws_security_group` rds | RDS 用 SG（ECS からの 5432 のみ許可） |

---

### rds.tf — データベース

| リソース | 内容 |
|---|---|
| `aws_db_subnet_group` | RDS を配置するサブネットのグループ（プライベート × 2AZ） |
| `aws_db_parameter_group` | PostgreSQL 設定（スロークエリログ 1秒以上を記録） |
| `aws_db_instance` | RDS 本体（db.t3.micro・20GB gp3・暗号化・7日バックアップ） |
| `aws_iam_role` rds_monitoring | RDS Enhanced Monitoring 用 IAM ロール |

---

### ecr.tf — コンテナイメージ管理

| リソース | 内容 |
|---|---|
| `aws_ecr_repository` backend | Spring Boot イメージの保管庫 |
| `aws_ecr_repository` frontend | React + Nginx イメージの保管庫 |
| `aws_ecr_lifecycle_policy` × 2 | 古いイメージを自動削除（最新 30 件を保持） |

---

### iam.tf — 権限管理

| リソース | 内容 |
|---|---|
| `aws_iam_role` ecs_task_execution | ECS エージェントが ECR・CloudWatch・Secrets Manager を操作する権限 |
| `aws_iam_role` ecs_task | コンテナ内アプリの権限（ECS Exec によるデバッグ接続） |
| `aws_iam_policy` ecs_secrets_access | Secrets Manager / SSM Parameter Store 読み取り権限 |
| `aws_iam_policy` ecs_exec | ECS Exec（コンテナへのシェル接続）権限 |

---

### alb.tf — ロードバランサー

| リソース | 内容 |
|---|---|
| `aws_lb` | ALB 本体（パブリックサブネット・2AZ） |
| `aws_lb_target_group` frontend | フロントエンド用（:80・ヘルスチェック: /health） |
| `aws_lb_target_group` backend | バックエンド用（:8080・ヘルスチェック: /actuator/health） |
| `aws_lb_listener` http | HTTP:80 リスナー（domain_name 設定時は HTTPS リダイレクト） |
| `aws_lb_listener` https | HTTPS:443 リスナー（domain_name 設定時のみ作成） |
| `aws_lb_listener_rule` api | `/api/*` をバックエンドに転送するルール |

---

### ecs.tf — コンテナ実行環境

| リソース | 内容 |
|---|---|
| `aws_cloudwatch_log_group` backend | バックエンドのログ（30日保持） |
| `aws_cloudwatch_log_group` frontend | フロントエンドのログ（30日保持） |
| `aws_ecs_cluster` | ECS クラスター（Container Insights 有効） |
| `aws_ecs_task_definition` backend | Spring Boot のコンテナ定義（0.5vCPU・1GB） |
| `aws_ecs_task_definition` frontend | React+Nginx のコンテナ定義（0.25vCPU・512MB） |
| `aws_ecs_service` backend | バックエンドを常時 1 台稼働・ALB 連携・自動ロールバック |
| `aws_ecs_service` frontend | フロントエンドを常時 1 台稼働・ALB 連携・自動ロールバック |

---

### acm.tf — SSL/TLS 証明書（ドメイン設定時のみ有効）

| リソース | 内容 |
|---|---|
| `aws_acm_certificate` | SSL/TLS 証明書の発行（無料・自動更新） |
| `aws_route53_record` acm_validation | DNS 検証用 CNAME レコード |
| `aws_acm_certificate_validation` | 証明書発行完了の待機 |

---

### route53.tf — DNS（ドメイン設定時のみ有効）

| リソース | 内容 |
|---|---|
| `data.aws_route53_zone` | 既存ホストゾーンの参照 |
| `aws_route53_record` app | `example.com` → ALB のエイリアス A レコード |
| `aws_route53_record` app_www | `www.example.com` → ALB のエイリアス A レコード |

---

## 4. AWSリソース一覧

`terraform plan` で確認できる作成予定リソース（合計 48 個）

| カテゴリ | リソース数 |
|---|---|
| ネットワーク（VPC・サブネット・IGW・NAT GW・ルートテーブル） | 13 |
| セキュリティグループ | 3 |
| RDS | 4 |
| ECR | 4 |
| IAM | 8 |
| ALB | 5 |
| ECS | 7 |
| CloudWatch Logs | 2 |
| ACM・Route 53 | ドメイン設定後に追加 |
| **合計** | **48** |

---

## 5. 変数・出力値

### 主要な変数（terraform.tfvars で設定）

| 変数名 | 値 | 説明 |
|---|---|---|
| `project_name` | `taskmanagement` | リソース名のプレフィックス |
| `environment` | `dev` | 環境名 |
| `aws_region` | `ap-northeast-1` | 東京リージョン |
| `vpc_cidr` | `10.0.0.0/16` | VPC の IP 範囲 |
| `db_instance_class` | `db.t3.micro` | RDS のサイズ（無料枠対象） |
| `db_password` | 環境変数で設定 | DB パスワード（ファイルに書かない） |
| `backend_cpu` | `512`（0.5vCPU） | ECS バックエンドの CPU |
| `backend_memory` | `1024`（1GB） | ECS バックエンドのメモリ |
| `domain_name` | `""`（空） | 独自ドメイン（未設定時は HTTP のみ） |

### 主要な出力値（terraform apply 後に確認できる値）

| 出力値名 | 内容 |
|---|---|
| `app_url` | アプリの公開 URL |
| `alb_dns_name` | ALB の DNS 名 |
| `spring_datasource_url` | Spring Boot の DB 接続 URL |
| `ecr_backend_repository_url` | バックエンド ECR の URL |
| `ecr_frontend_repository_url` | フロントエンド ECR の URL |
| `deploy_command_backend` | バックエンド再デプロイコマンド |
| `deploy_command_frontend` | フロントエンド再デプロイコマンド |

---

## 6. 運用スクリプト

### start-infra.sh — インフラ起動

```bash
export TF_VAR_db_password="パスワード"
./scripts/start-infra.sh
```

実行内容（自動）:
1. `terraform apply` — AWS にリソースを作成（約 15〜20 分）
2. `build-and-push.sh` — Docker ビルド & ECR プッシュ
3. `aws ecs update-service` — ECS を新イメージで再デプロイ
4. アプリの URL を表示

---

### stop-infra.sh — インフラ削除（課金停止）

```bash
export TF_VAR_db_password="パスワード"
./scripts/stop-infra.sh
```

実行内容（自動）:
1. 確認プロンプト（`yes` 入力で実行）
2. ECS タスクを 0 台に削減（高速化）
3. `terraform destroy` — 全リソースを削除（約 10〜15 分）

---

### build-and-push.sh — イメージ更新

```bash
# 全イメージをビルド & プッシュ
./scripts/build-and-push.sh

# バックエンドのみ
./scripts/build-and-push.sh --backend-only

# バージョンタグ付き
./scripts/build-and-push.sh --tag v1.0.0
```

---

## 7. デプロイフロー

```
開発者のPC
    │
    │ 1. コードを修正
    │
    ├─ ./scripts/build-and-push.sh
    │      │
    │      ├─ docker build（バックエンド）
    │      ├─ docker build（フロントエンド）
    │      └─ docker push → ECR
    │
    └─ aws ecs update-service（ECS 再デプロイ）
           │
           └─ ECS が ECR から新イメージを取得して起動
                  │
                  └─ ALB がヘルスチェック通過後にトラフィックを切り替え
```

---

## 8. コスト概算

| リソース | 月額（24h稼働） | 備考 |
|---|---|---|
| NAT Gateway × 2 | $65〜90 | 最大コスト要因 |
| ALB | $17〜20 | |
| ECS Fargate | $22〜27 | バックエンド+フロントエンド |
| RDS db.t3.micro | ほぼ無料 | 12ヶ月無料枠あり |
| ECR | 500MB まで無料 | |
| **合計（24h稼働）** | **$100〜130/月** | |

**学習中の推奨運用**: 使うときだけ `start-infra.sh` で起動し、終わったら `stop-infra.sh` で削除。1日3時間の利用で月 $13〜20 程度に抑えられる。
