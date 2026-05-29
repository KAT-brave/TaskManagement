# コードレビュー結果

レビュー実施日: 2026-05-29

---

## 1. 総合評価

**ポートフォリオとしての評価: ★★★★☆（4/5）**

初心者のポートフォリオとして、**十分に見せられる状態**です。レイヤー分割（Entity / DTO / Repository / Service / Controller）が正しく理解できており、品質管理の仕組みまで導入されている点は高く評価されます。

### 良い点

- **レイヤー構造が明確**: Entity / DTO / Service / Controller の役割が正しく分かれている
- **CardResponse でエンティティを直接返していない**: 外部に内部構造を漏らさない設計ができている（これができていないポートフォリオが多い）
- **@Valid + Bean Validation**: リクエスト検証が正しく実装されている
- **@Transactional**: 読み取り系に `readOnly = true` を使い分けており、理解が深い
- **GlobalExceptionHandler**: エラーレスポンスの統一ができている
- **ドラッグ&ドロップの position 永続化**: 画面操作がDBと連動している
- **2段階削除確認**: UXを意識した実装ができている
- **ESLint + Checkstyle**: 静的解析まで導入されている

### 改善した方がよい点

- `IllegalArgumentException` を「リソースが見つからない」の例外として使っているのは意味が合っていない
- `application.properties` の `show-sql=true` が開発・本番で切り替えられていない
- `cardApi.js` の `baseURL` がハードコードされている
- `Card` エンティティに `@PrePersist` / `@PreUpdate` がなく、日時管理が手動
- `GET /api/cards` が全カードを返す設計で、認証実装後に問題になる

---

## 2. 重要度別の指摘

### 🔴 高: 早めに直した方がよいもの

**【高-1】`IllegalArgumentException` は「リソースが見つからない」用の例外ではない**

- **対象**: `CardService.java`（35, 41, 63, 71, 82行目）、`GlobalExceptionHandler.java`
- **問題**: `IllegalArgumentException` は本来「引数が不正な値の場合」に投げる例外。「IDのカードが存在しない（404）」の意味合いではない。Spring では `NoSuchElementException` か、専用の例外クラス（例: `ResourceNotFoundException`）を作るのが一般的
- **修正案**:

```java
// 新規作成: exception/ResourceNotFoundException.java
public class ResourceNotFoundException extends RuntimeException {
    public ResourceNotFoundException(String message) {
        super(message);
    }
}

// GlobalExceptionHandler.java でキャッチするクラスを変更
@ExceptionHandler(ResourceNotFoundException.class)
@ResponseStatus(HttpStatus.NOT_FOUND)
public Map<String, String> handleNotFound(ResourceNotFoundException ex) {
    return Map.of("error", ex.getMessage());
}

// CardService.java 内の throw を変更
.orElseThrow(() -> new ResourceNotFoundException("Card not found: " + id));
```

---

**【高-2】`application.properties` が開発用設定のまま**

- **対象**: `backend/src/main/resources/application.properties`
- **問題**: `spring.jpa.show-sql=true` はSQLをコンソールに出力する開発用設定。本番環境では大量のログが出てパフォーマンスが悪化する。また `spring.jpa.hibernate.ddl-auto=update` も本番環境では危険（意図しないスキーマ変更が起きる）
- **修正案**: コメントで明示する

```properties
# 開発環境用設定（本番では false に変更すること）
spring.jpa.show-sql=true
# 本番環境では none または validate に変更すること
spring.jpa.hibernate.ddl-auto=update
```

---

**【高-3】`cardApi.js` の `baseURL` がハードコード**

- **対象**: `frontend/src/api/cardApi.js`（4行目）
- **問題**: `http://localhost:8080` が直接書かれているため、本番環境へのデプロイ時に毎回変更が必要。Vite には環境変数（`.env` ファイル）の仕組みがある
- **修正案**:

```js
// .env.development ファイルを作成
VITE_API_BASE_URL=http://localhost:8080

// cardApi.js
const api = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL,
});
```

---

### 🟡 中: できれば直した方がよいもの

**【中-1】日時の自動管理（`@PrePersist` / `@PreUpdate`）が未設定**

- **対象**: `Card.java`
- **問題**: `createdAt` と `updatedAt` の設定が `CardService` 内に手書きされている。エンティティ側で自動化するのが標準的な書き方
- **修正案**:

```java
@PrePersist
protected void onCreate() {
    this.createdAt = LocalDateTime.now();
    this.updatedAt = LocalDateTime.now();
}

@PreUpdate
protected void onUpdate() {
    this.updatedAt = LocalDateTime.now();
}
```

こうすると `CardService` の `setCreatedAt` / `setUpdatedAt` を削除でき、書き忘れも防げる。

---

**【中-2】`CardUpdateRequest` の `@Pattern` が `null` を許容していない**

- **対象**: `CardUpdateRequest.java`（21行目）
- **問題**: `null` の場合に更新しないという意図が不明確
- **修正案**: コメントで意図を明示する

```java
// nullの場合は更新しない（部分更新のため）
@Pattern(regexp = "^(high|medium|low)$", message = "優先度はhigh、medium、lowのいずれかを指定してください")
private String priority;
```

---

**【中-3】`GET /api/cards` が全カードを返す設計**

- **対象**: `CardController.java` / `CardService.java`
- **問題**: 認証を実装した後は「ログイン中のユーザーが所属するボードのカードのみ」にフィルタリングが必要になる。将来の認証実装時に設計変更が発生する
- **修正案**: 将来 `/api/boards/{boardId}/cards` や `/api/lists/{listId}/cards` のような階層的なURLに変更することを念頭に置く

---

**【中-4】`CreateCardForm` に優先度入力がない**

- **対象**: `CreateCardForm.jsx`
- **問題**: カード作成時に優先度を設定できず、必ず編集モーダルを開く必要がある。`EditCardModal` には優先度フィールドがあるので一貫性がない
- **修正案**: `CreateCardForm` に優先度の `<select>` を追加する

---

**【中-5】`CardRepository.findByListId()` の命名**

- **対象**: `CardRepository.java`（9行目）
- **問題**: `Card` エンティティでは `list`（`TaskList` オブジェクト）を持っているが、`findByListId` は `list.id` を指す書き方として `findByList_Id` の方が明示的
- **修正案**:

```java
// より明確な書き方
List<Card> findByList_Id(Long listId);
// または
@Query("SELECT c FROM Card c WHERE c.list.id = :listId")
List<Card> findByListId(@Param("listId") Long listId);
```

---

### 🟢 低: 余裕があれば直すもの

**【低-1】`KanbanColumn` の `ref` の設置場所**

- **対象**: `KanbanColumn.jsx`（18行目）
- **問題**: `useDroppable` の `setNodeRef` が `cards-list` div に設定されているが、`list-column` 全体に設定する方が空のリストにドロップしやすくなる

**【低-2】`CardItem` のクリックとドラッグの競合**

- **対象**: `CardItem.jsx`（38行目）
- **問題**: `onClick` と `{...listeners}` が同じ div に設定されているため、ドラッグ操作後にモーダルが開いてしまうことがある
- **修正案**:

```jsx
onClick={() => { if (!isDragging) setEditing(true); }}
```

**【低-3】エラーメッセージが英語**

- **対象**: `CardService.java`（"Card not found: " 等）
- **問題**: `GlobalExceptionHandler` で日本語エラーを返しているが、元のメッセージが英語で混在している
- **修正案**: メッセージを日本語に統一するか定数化する

---

## 3. ファイル別レビュー

| ファイル | 評価 | 主な指摘 |
|---------|------|---------|
| `Card.java` | ★★★★☆ | `@PrePersist/@PreUpdate` がなく日時が手動管理 |
| `CardController.java` | ★★★★★ | 問題なし。`@ResponseStatus` の使い分けも正しい |
| `CardService.java` | ★★★★☆ | `IllegalArgumentException` の用途が不適切 |
| `CardCreateRequest.java` | ★★★★★ | 問題なし。バリデーションも適切 |
| `CardUpdateRequest.java` | ★★★★☆ | `null` 許容の意図が不明確 |
| `CardResponse.java` | ★★★★★ | エンティティを直接返さない設計が正しい |
| `GlobalExceptionHandler.java` | ★★★★☆ | `IllegalArgumentException` のキャッチが不適切 |
| `SecurityConfig.java` | ★★★★☆ | CORS設定は良い。認証実装後に大幅変更必要 |
| `CardRepository.java` | ★★★★☆ | `findByListId` の命名が微妙 |
| `cardApi.js` | ★★★☆☆ | `baseURL` のハードコードが問題 |
| `BoardPage.jsx` | ★★★★☆ | `useCallback` 対応済みで良い |
| `KanbanColumn.jsx` | ★★★★☆ | `ref` の設置場所が微妙 |
| `CardItem.jsx` | ★★★★☆ | クリック/ドラッグの競合が残る |
| `CreateCardForm.jsx` | ★★★★☆ | 優先度フィールドがない |
| `EditCardModal.jsx` | ★★★★★ | 2段階削除確認まで実装されており良い |
| `application.properties` | ★★★☆☆ | 開発用設定のまま（show-sql, ddl-auto） |

---

## 4. 次に作るべきIssue案

### Issue A（推奨度: 高）

- **タイトル**: `refactor: ResourceNotFoundException を導入して例外処理を適切に分類する`
- **目的**: `IllegalArgumentException` の誤用を修正し、404と400を正しく使い分ける
- **作業内容**:
  1. `exception/ResourceNotFoundException.java` を新規作成
  2. `CardService.java` の `throw` を置き換える
  3. `GlobalExceptionHandler.java` のキャッチ対象を変更
- **完了条件**: 存在しないIDにアクセスすると `{"error": "..."}` + 404が返る

### Issue B（推奨度: 高）

- **タイトル**: `chore: 環境変数を使って baseURL をハードコードから分離する`
- **目的**: 本番デプロイ時に毎回コードを変更しなくて済むようにする
- **作業内容**:
  1. `.env.development` に `VITE_API_BASE_URL=http://localhost:8080` を追加
  2. `.env.example` を作成してリポジトリに追加
  3. `cardApi.js` を `import.meta.env.VITE_API_BASE_URL` に変更
- **完了条件**: `.env` を変更するだけで接続先を切り替えられる

### Issue C（推奨度: 中）

- **タイトル**: `refactor: @PrePersist/@PreUpdate でエンティティの日時を自動管理する`
- **目的**: 更新日時の設定漏れを防ぎ、Service の責務をシンプルにする
- **作業内容**:
  1. `Card.java` に `@PrePersist` / `@PreUpdate` メソッドを追加
  2. `CardService.java` の `setCreatedAt` / `setUpdatedAt` を削除
- **完了条件**: `mvn validate` が通り、カード作成・更新で日時が正しく保存される

### Issue D（推奨度: 中）

- **タイトル**: `feat: カード作成フォームに優先度フィールドを追加する`
- **目的**: カード作成時から優先度を設定できるようにする
- **作業内容**:
  1. `CreateCardForm.jsx` に優先度の `<select>` を追加
  2. `createCard()` APIコールに `priority` を含める
- **完了条件**: カード作成フォームで優先度を選択でき、作成後のカードに優先度バッジが表示される

---

## 5. 初心者向けの学習ポイント

### 今回の実装で理解すべき重要ポイント

**1. なぜ Entity を直接 API レスポンスで返してはいけないのか**

- エンティティには DB のパスワードや内部IDなど、外部に漏らしてはいけない情報が含まれることがある
- エンティティの構造を変えると API のレスポンス形式も変わってしまい、フロントエンドが壊れる
- `CardResponse` のように DTO を間に挟むことで「内部の都合」と「外部への契約」を切り離せる

**2. `@Transactional(readOnly = true)` を使う理由**

- 読み取り専用トランザクションはDBへの更新ロックを取得しないため、複数のリクエストが競合しにくい
- Hibernate がダーティチェック（変更検出）をスキップするためパフォーマンスが上がる
- 「これは読み取りしかしない」という意図がコードに明示される

**3. ドラッグ&ドロップで position を保存する設計**

- フロント側で `arrayMove` で表示順を変えた後、各カードの新しい position を API に送信している
- リロードしても順番が維持されるのは、この position がDB に保存されているから
- 「楽観的UI更新」（APIのレスポンスを待たずに画面を先に変える）の考え方が使われている

**4. なぜ `useCallback` が必要だったか**

- `loadCards` を `useCallback` でメモ化しないと、`BoardPage` が再レンダリングされるたびに新しい関数が生成される
- 新しい関数が生成されると `useEffect` の依存配列が変化したと判定され、無限ループになる
- `useCallback(fn, [])` で「初回のみ関数を作成し、以降は同じ関数を使い回す」と宣言できる

---

### 面接・ポートフォリオ説明で話せるポイント

| 質問 | 答えられるべきこと |
|------|-----------------|
| 「なぜ React を使いましたか？」 | コンポーネント指向で再利用しやすい、ドラッグ&ドロップライブラリが充実している |
| 「Spring Boot で工夫した点は？」 | レイヤー分割（Entity/DTO/Service/Controller）の徹底、@Transactional・Bean Validation・GlobalExceptionHandler で品質を担保 |
| 「ドラッグ&ドロップはどう実装しましたか？」 | @dnd-kit を使い、ドロップ後に position と listId をAPIで保存することでリロード後も順番を維持 |
| 「エラーハンドリングはどうしていますか？」 | GlobalExceptionHandler（@RestControllerAdvice）で404・400を JSON形式に統一している |
| 「品質管理はどうしていますか？」 | フロントは ESLint、バックエンドは Checkstyle で静的解析を導入している |
