# =============================================================================
# backend/Dockerfile
# =============================================================================
# マルチステージビルドを使う
# 「マルチステージビルド」= ビルド用の環境と実行用の環境を分けること
#
# メリット:
#   - ビルドツール（Maven, JDK）を最終イメージに含めない
#   - イメージサイズが大幅に小さくなる（例: 600MB → 200MB）
#   - セキュリティリスクが減る（不要なツールが入らない）

# =============================================================================
# Stage 1: ビルドステージ
# =============================================================================
# Maven + JDK 25 のイメージでアプリをビルドする
FROM eclipse-temurin:25-jdk-alpine AS builder

WORKDIR /build

# 依存関係のキャッシュを活かすため、pom.xml を先にコピーしてダウンロードする
# pom.xml が変わらない限り、この層はキャッシュされてビルドが速くなる
COPY pom.xml .
COPY mvnw .
COPY .mvn .mvn

# 依存関係をダウンロード（ソースコードなし）
RUN ./mvnw dependency:go-offline -B

# ソースコードをコピーしてビルド
COPY src ./src
RUN ./mvnw package -DskipTests -B

# ビルド結果の JAR ファイルを確認（デバッグ用）
RUN ls -lh target/*.jar

# =============================================================================
# Stage 2: 実行ステージ
# =============================================================================
# JRE（実行環境のみ）の軽量イメージを使う
# JDK（開発ツール含む）は不要なので JRE だけにする
FROM eclipse-temurin:25-jre-alpine AS runtime

# セキュリティのため root 以外のユーザーで実行する
# root で動かすと、コンテナが侵害された場合のリスクが高くなる
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Stage 1 でビルドした JAR ファイルだけをコピーする
COPY --from=builder /build/target/*.jar app.jar

# appuser に所有権を変更
RUN chown appuser:appgroup app.jar

USER appuser

# Spring Boot のデフォルトポート
EXPOSE 8080

# ヘルスチェック: ALBが「このコンテナは正常か」を確認するのに使う
# --interval=30s: 30秒ごとにチェック
# --timeout=5s: 5秒以内に応答がなければ失敗とみなす
# --retries=3: 3回失敗したら unhealthy とみなす
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD wget -qO- http://localhost:8080/actuator/health || exit 1

# JVM のメモリ設定を環境変数で渡せるようにする
# ECS のタスク定義から JAVA_OPTS を上書きできる
ENV JAVA_OPTS="-Xms256m -Xmx512m"

# アプリを起動する
# exec 形式（配列）にすることで、シグナル（停止命令）が正しく届く
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
