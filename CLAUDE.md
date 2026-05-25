# TaskManagement - Claude Code ルール

## 必須ワークフロー

### 作業開始前に必ずIssueを作成する

```bash
gh issue create --title "feat: タスクの説明" --body "## 概要\n実施内容を記述"
```

Issueを作成したら番号（例: #5）を記録し、以降の作業に使用する。

### ブランチ命名規則

| 種別 | 命名パターン | 例 |
|------|------------|-----|
| 新機能 | `feature/issue-{N}-説明` | `feature/issue-5-add-task-api` |
| バグ修正 | `fix/issue-{N}-説明` | `fix/issue-8-fix-login-error` |
| 雑務・ドキュメント | `chore/issue-{N}-説明` | `chore/issue-3-update-readme` |

```bash
# ブランチ作成例
git checkout -b feature/issue-5-add-task-api
```

### mainへの直接プッシュ禁止

- `main` ブランチへの直接 `git push` は禁止
- 必ずfeature/fix/choreブランチで作業し、PRを作成してマージする

### PRの作成

```bash
gh pr create --title "feat: タスク一覧APIの追加 (closes #5)" --body "..."
```

- タイトルにIssue番号を含める（`closes #N` でIssueを自動クローズ）
- PRテンプレート（`.github/pull_request_template.md`）に従って記述する

---

## スタック情報

| 役割 | 技術 |
|------|------|
| バックエンド | Java 21 / Spring Boot 4 |
| フロントエンド | React（予定） |
| 認証 | Spring Security |
| データベース | PostgreSQL 16 |
| ORM | JPA / Hibernate |
| ビルド | Maven |

### 開発環境の起動

```bash
# DBをDockerで起動（作業前に必須）
docker compose up -d

# バックエンド起動
export PATH="/opt/homebrew/opt/openjdk@21/bin:$PATH"
cd backend && ./mvnw spring-boot:run
```

DB接続情報: `localhost:5432` / DB名: `taskmanagement` / ユーザー: `postgres` / パスワード: `password`
