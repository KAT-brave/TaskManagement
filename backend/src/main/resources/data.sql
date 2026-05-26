-- テストデータ投入（存在しない場合のみ挿入）

INSERT INTO users (name, email, password_digest, created_at, updated_at)
SELECT 'テストユーザー', 'test@example.com', 'hashed_password', NOW(), NOW()
WHERE NOT EXISTS (SELECT 1 FROM users WHERE email = 'test@example.com');

INSERT INTO boards (user_id, name, created_at, updated_at)
SELECT 1, '開発タスクボード', NOW(), NOW()
WHERE NOT EXISTS (SELECT 1 FROM boards WHERE name = '開発タスクボード');

INSERT INTO lists (board_id, name, position, created_at, updated_at)
SELECT 1, 'ToDo', 1, NOW(), NOW()
WHERE NOT EXISTS (SELECT 1 FROM lists WHERE board_id = 1 AND name = 'ToDo');

INSERT INTO lists (board_id, name, position, created_at, updated_at)
SELECT 1, '進行中', 2, NOW(), NOW()
WHERE NOT EXISTS (SELECT 1 FROM lists WHERE board_id = 1 AND name = '進行中');

INSERT INTO lists (board_id, name, position, created_at, updated_at)
SELECT 1, '完了', 3, NOW(), NOW()
WHERE NOT EXISTS (SELECT 1 FROM lists WHERE board_id = 1 AND name = '完了');

INSERT INTO cards (list_id, title, description, due_date, position, created_at, updated_at)
SELECT 1, 'ログイン機能の実装', 'Spring SecurityでJWT認証を実装する', '2026-06-01', 1, NOW(), NOW()
WHERE NOT EXISTS (SELECT 1 FROM cards WHERE title = 'ログイン機能の実装');

INSERT INTO cards (list_id, title, description, due_date, position, created_at, updated_at)
SELECT 1, 'ユーザー登録APIの作成', 'POST /api/users エンドポイントを作成する', '2026-06-05', 2, NOW(), NOW()
WHERE NOT EXISTS (SELECT 1 FROM cards WHERE title = 'ユーザー登録APIの作成');

INSERT INTO cards (list_id, title, description, due_date, position, created_at, updated_at)
SELECT 2, 'カード読み取りAPIの実装', 'GET /api/cards エンドポイントを実装する', '2026-05-25', 1, NOW(), NOW()
WHERE NOT EXISTS (SELECT 1 FROM cards WHERE title = 'カード読み取りAPIの実装');

INSERT INTO cards (list_id, title, description, due_date, position, created_at, updated_at)
SELECT 3, 'Docker環境構築', 'PostgreSQLをDockerで動かす設定を追加した', '2026-05-20', 1, NOW(), NOW()
WHERE NOT EXISTS (SELECT 1 FROM cards WHERE title = 'Docker環境構築');
