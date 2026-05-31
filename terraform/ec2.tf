# =============================================================================
# EC2（Elastic Compute Cloud）
# =============================================================================
# EC2 = AWS の仮想サーバー
# t3.micro = 2vCPU・1GB RAM（12ヶ月無料枠対象）
#
# このファイルで作るもの:
#   - SSH キーペア（サーバーへのログインに使う）
#   - EC2 インスタンス（Java 21 + Nginx をインストール済みで起動）
#   - Elastic IP（固定パブリック IP アドレス）

# =============================================================================
# SSH キーペア
# =============================================================================
# キーペア = 公開鍵（AWS に登録）と秘密鍵（手元に保管）のセット
# SSH でサーバーにログインするときにパスワードの代わりに使う
#
# 【事前準備】ターミナルで以下を実行して SSH キーを作成しておく:
#   ssh-keygen -t ed25519 -C "taskmanagement" -f ~/.ssh/taskmanagement
#   → ~/.ssh/taskmanagement     (秘密鍵: 絶対に人に渡さない)
#   → ~/.ssh/taskmanagement.pub (公開鍵: AWS に登録する)

resource "aws_key_pair" "main" {
  key_name   = "${var.project_name}-key"
  public_key = file(var.ssh_public_key_path)
  # var.ssh_public_key_path = "~/.ssh/taskmanagement.pub" (terraform.tfvars で設定)

  tags = {
    Name = "${var.project_name}-key"
  }
}

# =============================================================================
# AMI（Amazon Machine Image）の取得
# =============================================================================
# AMI = OS のテンプレート（ここから EC2 が起動する）
# Amazon Linux 2023 = AWS が提供する最新の Linux ディストリビューション
# Java 21 が公式リポジトリから簡単にインストールできる

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# =============================================================================
# EC2 インスタンス
# =============================================================================

resource "aws_instance" "main" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.ec2_instance_type  # t3.micro（無料枠）
  subnet_id              = aws_subnet.public[0].id  # パブリックサブネットに配置
  vpc_security_group_ids = [aws_security_group.ec2.id]
  key_name               = aws_key_pair.main.key_name

  # ルートボリューム（OS が入るディスク）
  root_block_device {
    volume_type = "gp3"
    volume_size = 20    # 20GB（無料枠: 30GB まで無料）
    encrypted   = true  # 暗号化
  }

  # ==========================================================================
  # ユーザーデータ（インスタンス起動時に自動実行されるスクリプト）
  # ==========================================================================
  # サーバーが起動した直後に Java 21 と Nginx を自動でインストールする
  # ssh でログインしなくても最初から使える状態にする

  user_data = <<-EOF
    #!/bin/bash
    set -e

    # ログをファイルに出力（/var/log/user-data.log で確認できる）
    exec > >(tee /var/log/user-data.log | logger -t user-data) 2>&1
    echo "=== EC2 セットアップ開始: $(date) ==="

    # パッケージの更新
    dnf update -y

    # Java 25（Amazon Corretto）のインストール
    # Corretto 25 は Amazon Linux 2023 の標準リポジトリ未収録のため RPM を直接取得する
    dnf install -y java-25-amazon-corretto-headless || {
      echo "dnf 経由で失敗。RPM を直接ダウンロードしてインストールします..."
      rpm --import https://apt.corretto.aws/corretto.key
      curl -Lo /tmp/corretto25.rpm \
        "https://corretto.aws/downloads/latest/amazon-corretto-25-x64-linux-jdk.rpm"
      dnf install -y /tmp/corretto25.rpm
      rm /tmp/corretto25.rpm
    }
    echo "Java バージョン: $(java -version 2>&1 | head -1)"

    # Nginx のインストール
    dnf install -y nginx
    systemctl enable nginx
    systemctl start nginx
    echo "Nginx: $(nginx -v 2>&1)"

    # アプリケーション配置ディレクトリの作成
    mkdir -p /opt/taskmanagement
    chown ec2-user:ec2-user /opt/taskmanagement

    # Spring Boot 用の systemd サービスファイルを作成
    # systemd = Linux のサービス管理システム（起動・停止・自動再起動など）
    cat > /etc/systemd/system/taskmanagement.service << 'SERVICE'
    [Unit]
    Description=TaskManagement Spring Boot Application
    After=network.target

    [Service]
    Type=simple
    User=ec2-user
    WorkingDirectory=/opt/taskmanagement
    ExecStart=/usr/bin/java -jar /opt/taskmanagement/app.jar
    Restart=on-failure
    RestartSec=10
    StandardOutput=journal
    StandardError=journal
    SyslogIdentifier=taskmanagement

    [Install]
    WantedBy=multi-user.target
    SERVICE

    systemctl daemon-reload
    # ※ app.jar を配置してから手動で起動する:
    #   sudo systemctl start taskmanagement

    # Nginx の設定（フロントエンド配信 + /api/* をバックエンドへプロキシ）
    cat > /etc/nginx/conf.d/taskmanagement.conf << 'NGINX'
    server {
        listen 80;
        server_name _;

        # フロントエンドの静的ファイル
        root /opt/taskmanagement/frontend;
        index index.html;

        # /api/* はバックエンド（Spring Boot）へ転送
        location /api/ {
            proxy_pass http://localhost:8080;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }

        # ヘルスチェック
        location /health {
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }

        # SPA ルーティング（React の直接 URL アクセス対応）
        location / {
            try_files $uri $uri/ /index.html;
        }
    }
    NGINX

    # フロントエンド配置ディレクトリの作成
    mkdir -p /opt/taskmanagement/frontend
    chown -R ec2-user:ec2-user /opt/taskmanagement/frontend

    # Nginx をリロード（設定を反映）
    nginx -t && systemctl reload nginx

    echo "=== EC2 セットアップ完了: $(date) ==="
  EOF

  tags = {
    Name = "${var.project_name}-server"
  }
}

# =============================================================================
# Elastic IP（固定パブリック IP アドレス）
# =============================================================================
# EC2 は再起動するたびにパブリック IP が変わる
# Elastic IP を使うと IP が固定されてドメインとの紐付けが安定する
# ※ EC2 に関連付けている間は無料。EC2 を停止・削除すると課金されるので注意

resource "aws_eip" "main" {
  instance = aws_instance.main.id
  domain   = "vpc"

  depends_on = [aws_internet_gateway.main]

  tags = {
    Name = "${var.project_name}-eip"
  }
}
