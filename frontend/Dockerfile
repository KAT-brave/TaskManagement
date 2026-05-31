# =============================================================================
# frontend/Dockerfile
# =============================================================================
# マルチステージビルド
#   Stage 1: Node.js で React アプリをビルドして静的ファイル（HTML/JS/CSS）を生成
#   Stage 2: Nginx でその静的ファイルを配信する

# =============================================================================
# Stage 1: ビルドステージ
# =============================================================================
FROM node:22-alpine AS builder

WORKDIR /build

# 依存関係のキャッシュを活かすため、package.json を先にコピー
# package.json が変わらない限り npm install の層はキャッシュされる
COPY package.json package-lock.json ./
RUN npm ci --frozen-lockfile

# ソースコードをコピーしてビルド
COPY . .

# ビルド時の環境変数（バックエンドAPIのURL）
# デフォルトは /api/（Nginx プロキシ経由）
# ビルド時に --build-arg で上書きできる
ARG VITE_API_BASE_URL=/api
ENV VITE_API_BASE_URL=${VITE_API_BASE_URL}

# React アプリをビルドして dist/ に静的ファイルを生成
RUN npm run build

# ビルド結果を確認（デバッグ用）
RUN ls -lh dist/

# =============================================================================
# Stage 2: 実行ステージ（Nginx）
# =============================================================================
FROM nginx:1.27-alpine AS runtime

# カスタム Nginx 設定を配置
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Stage 1 でビルドした静的ファイルを Nginx の公開ディレクトリにコピー
COPY --from=builder /build/dist /usr/share/nginx/html

# ヘルスチェック
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:80/health || exit 1

EXPOSE 80

# Nginx をフォアグラウンドで起動（デーモン化しない）
# Docker コンテナは PID 1 のプロセスが終了すると停止するため
CMD ["nginx", "-g", "daemon off;"]
