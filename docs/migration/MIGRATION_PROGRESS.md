# GraphQL移行進捗記録

## 完了した作業

### ✅ フェーズ1: GraphQL基盤構築 (完了)

#### バックエンド
- [x] GraphQL gem インストール (`graphql`, `graphql-batch`, `graphiql-rails`)
- [x] GraphQL初期化 (`rails generate graphql:install`)
- [x] GraphQLコントローラー作成 (`/graphql` エンドポイント)
- [x] Context設定 (current_user注入)
- [x] 基本Type定義 (UserType, SessionType)
- [x] セッションQuery実装 (`currentSession`)

**エンドポイント**: `POST /graphql`

**動作確認**:
```bash
curl -X POST http://localhost:3001/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "{ currentSession { isLoggedIn userId } }"}'
```

**レスポンス**:
```json
{
  "data": {
    "currentSession": {
      "isLoggedIn": false,
      "userId": null
    }
  }
}
```

#### フロントエンド
- [ ] Apollo Client インストール (未着手)
- [ ] GraphQL Code Generator セットアップ (未着手)
- [ ] セッションクエリの移行 (未着手)

---

## 現在の課題と注意点

### 🚧 課題1: API-onlyモードでGraphiQLが使えない

**問題**: Rails API-onlyモードのため、GraphiQLの開発UIが使えない

**対策**:
- 外部ツール使用: [GraphiQL.app](https://github.com/skevy/graphiql-app) または Postman
- または開発環境のみAPI-onlyを解除してGraphiQLをマウント

**一時的な解決策**: curlでテスト

---

### 🚧 課題2: SessionTypeの設計

**問題**: 最初の実装でnull処理が不適切だった

**解決**:
- SessionTypeを常にハッシュで返すように変更
- `is_logged_in`, `user_id`, `user`のフィールドで状態を表現

**コード**:
```ruby
def current_session
  {
    is_logged_in: context[:current_user].present?,
    user_id: context[:current_user]&.id,
    user: context[:current_user]
  }
end
```

---

### 🚧 課題3: GraphQL自動生成時の構文エラー

**問題**: `config/application.rb`にGraphQL設定追加時に余分なカンマが挿入された

**修正内容**:
```ruby
# 修正前
config.active_record.query_log_tags = [
  :application, :controller, :action, :job,
,  # ← 余分なカンマ
  current_graphql_operation: -> { GraphQL::Current.operation_name },
]

# 修正後
config.active_record.query_log_tags = [
  :application, :controller, :action, :job,
  current_graphql_operation: -> { GraphQL::Current.operation_name },
]
```

**教訓**: GraphQL generatorの自動挿入コードは必ず確認する

---

## 次のステップ

### Phase 2: フロントエンド - Apollo Client セットアップ

#### 必要な作業
1. パッケージインストール
   ```bash
   npm install @apollo/client graphql
   npm install --save-dev @graphql-codegen/cli @graphql-codegen/typescript @graphql-codegen/typescript-operations @graphql-codegen/typescript-react-apollo
   ```

2. Apollo Client設定
   - `src/lib/apollo/client.ts` 作成
   - Cookie認証の設定 (`credentials: 'include'`)

3. GraphQL Code Generator設定
   - `codegen.yml` 作成
   - スキーマURL設定: `http://localhost:3001/graphql`
   - 生成先: `src/generated/graphql.ts`

4. セッションクエリ移行
   - `src/graphql/queries/session.graphql` 作成
   - `useSession` hook実装
   - 既存のZodios実装と並行稼働

---

## 今後の移行優先順位

### 高優先度 (すぐに移行可能)
1. **セッション管理** ✅ (バックエンド完了)
   - シンプルな構造
   - 全ページで使用
   - REST APIと並行稼働可能

2. **ユーザー情報取得**
   - UserTypeが既に定義済み
   - `getUser(id: ID!)` クエリ追加

3. **フォロー状態取得**
   - UserType.is_followingフィールド実装済み
   - N+1問題をgraphql-batchで解決

### 中優先度 (設計が必要)
4. **何切る問題一覧**
   - カーソルベースページネーション実装
   - Connection/Edgeパターン適用

5. **何切る問題詳細**
   - 問題情報 + 投票結果 + コメントを1クエリで取得
   - 複雑なネスト構造の設計

### 低優先度 (Mutation実装が必要)
6. **フォロー/フォロー解除**
   - Mutation実装
   - 楽観的UI更新

7. **投票機能**
   - Mutation実装
   - キャッシュ更新戦略

8. **いいね機能**
   - Mutation実装

9. **コメント機能**
   - CRUD Mutation実装
   - ネストしたコメント対応

---

## ハマりポイントメモ

### 1. GraphQL nullableフィールドの設計

**問題**: `null: false`の適用タイミング

**ルール**:
- Queryフィールド: 必ず値を返せる場合のみ `null: false`
- Type内フィールド: DBのNOT NULL制約に合わせる
- ログイン不要なクエリ: `null: true` を使う

**例**:
```ruby
# OK: 常にセッション情報を返す
field :current_session, Types::SessionType, null: false

# NG: current_userがnilの場合がある
field :current_user, Types::UserType, null: false  # ← エラーになる

# OK
field :current_user, Types::UserType, null: true
```

### 2. Context設定の重要性

**必須**: GraphQLController で`current_user`をcontextに注入

```ruby
context = {
  current_user: current_user,
}
```

これを忘れるとType内で`context[:current_user]`がnilになる

### 3. REST APIとの並行稼働

**方針**:
- REST APIは残したまま、GraphQLを追加
- フロントエンドで段階的に切り替え
- 両方のエンドポイントが同じcurrent_userを参照

**メリット**:
- ロールバック可能
- A/Bテスト可能
- 段階的移行でリスク最小化

---

## パフォーマンス測定

### ベンチマーク (予定)

#### REST API (現状)
- セッション取得: `GET /session`
- ユーザー取得: `GET /users/:id`
- フォロー状態取得: `GET /users/:id/follow`

**総リクエスト数**: 3回

#### GraphQL (目標)
```graphql
{
  currentSession {
    isLoggedIn
    userId
    user {
      id
      name
      avatarUrl
      isFollowing
    }
  }
}
```

**総リクエスト数**: 1回

**削減率**: 66% (3回 → 1回)

---

## 完了条件

### Phase 1完了条件 ✅
- [x] GraphQL gem インストール
- [x] 基本Type定義
- [x] セッションクエリ実装
- [x] 動作確認

### Phase 2完了条件 (次)
- [ ] Apollo Client セットアップ
- [ ] Code Generator設定
- [ ] フロントエンドでセッションクエリ実装
- [ ] REST APIとの並行稼働確認

### 最終完了条件
- [ ] 全REST APIをGraphQLに移行
- [ ] パフォーマンス改善確認 (API呼び出し50%削減)
- [ ] REST API廃止
- [ ] ドキュメント整備

---

## 参考リンク

- [GraphQL Ruby公式](https://graphql-ruby.org/)
- [Apollo Client公式](https://www.apollographql.com/docs/react/)
- [GraphQL Code Generator](https://the-guild.dev/graphql/codegen)
- [移行計画書](./GRAPHQL_MIGRATION_PLAN.md)