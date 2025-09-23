# GraphQL移行計画

## 目次
1. [現状分析](#現状分析)
2. [移行戦略](#移行戦略)
3. [実装計画](#実装計画)
4. [段階的移行ロードマップ](#段階的移行ロードマップ)
5. [技術スタック](#技術スタック)
6. [リスクと対策](#リスクと対策)

---

## 現状分析

### 現在のREST API構成

**エンドポイント数**: 25コントローラー

#### 主要ドメイン

1. **認証 (Auth)**
   - メール認証 (トークンベース)
   - Google OAuth
   - LINE OAuth
   - セッション管理

2. **ユーザー (Users)**
   - ユーザーCRUD
   - フォロー/フォロワー
   - プロフィール管理
   - 退会処理

3. **何切る問題 (WhatToDiscardProblems)**
   - 問題CRUD
   - 投票機能
   - コメント/返信機能
   - いいね機能

4. **学習 (Learnings)**
   - カテゴリ管理
   - 質問管理

### REST APIの課題

1. **Over-fetching/Under-fetching**
   - ユーザー情報取得時に不要なフィールドも取得
   - ネストしたリソース取得に複数リクエストが必要
   - 例: 問題詳細 + 投票結果 + コメント = 3リクエスト

2. **N+1問題**
   - 問題一覧でユーザー情報を都度取得
   - コメント一覧でユーザー情報を都度取得

3. **エンドポイントの増加**
   - リソースごとに専用エンドポイントが必要
   - `/my_vote`, `/my_like` など状態取得専用エンドポイント

4. **フロントエンド開発の非効率性**
   - 複数APIを組み合わせる必要がある
   - Zodiosクライアント生成による型安全性はあるが柔軟性に欠ける

---

## 移行戦略

### アプローチ: ハイブリッド移行

REST APIとGraphQLを並行稼働させ、段階的に移行する。

#### メリット
- リスク最小化
- 段階的な学習とテスト
- 既存機能への影響なし
- ロールバック可能

#### デメリット
- 一時的なメンテナンスコスト増加
- 二重管理期間が発生

---

## 実装計画

### フェーズ1: GraphQL基盤構築 (Week 1-2)

#### バックエンド (Rails)

**1. Gemインストール**
```ruby
# Gemfile
gem 'graphql'
gem 'graphql-batch' # N+1問題解決
gem 'graphiql-rails', group: :development # GraphQL IDE
```

**2. GraphQL初期化**
```bash
bundle install
rails generate graphql:install
```

**3. 基本構成**
```
api/app/graphql/
├── types/
│   ├── base_object.rb
│   ├── base_enum.rb
│   ├── base_union.rb
│   ├── base_interface.rb
│   └── query_type.rb
├── mutations/
│   └── base_mutation.rb
├── resolvers/
│   └── base_resolver.rb
└── api_app_schema.rb
```

#### フロントエンド (Next.js)

**1. パッケージインストール**
```bash
npm install @apollo/client graphql
npm install --save-dev @graphql-codegen/cli @graphql-codegen/typescript @graphql-codegen/typescript-operations @graphql-codegen/typescript-react-apollo
```

**2. Apollo Clientセットアップ**
```typescript
// src/lib/apollo/client.ts
import { ApolloClient, InMemoryCache, createHttpLink } from '@apollo/client';

const httpLink = createHttpLink({
  uri: process.env.NEXT_PUBLIC_GRAPHQL_ENDPOINT,
  credentials: 'include', // Cookie送信
});

export const apolloClient = new ApolloClient({
  link: httpLink,
  cache: new InMemoryCache(),
});
```

**3. GraphQL Code Generator設定**
```yaml
# codegen.yml
schema: http://localhost:3001/graphql
documents: 'src/**/*.graphql'
generates:
  src/generated/graphql.ts:
    plugins:
      - typescript
      - typescript-operations
      - typescript-react-apollo
```

---

### フェーズ2: パイロット実装 (Week 3-4)

#### 対象: セッション管理

**理由**:
- シンプルな構造
- 全ページで使用される重要機能
- GraphQLの基本概念を学習しやすい

#### バックエンド実装

**1. Type定義**
```ruby
# app/graphql/types/session_type.rb
module Types
  class SessionType < Types::BaseObject
    field :is_logged_in, Boolean, null: false
    field :user_id, Integer, null: true
    field :user, Types::UserType, null: true
  end
end
```

**2. Query実装**
```ruby
# app/graphql/types/query_type.rb
module Types
  class QueryType < Types::BaseObject
    field :current_session, Types::SessionType, null: false

    def current_session
      {
        is_logged_in: context[:current_user].present?,
        user_id: context[:current_user]&.id,
        user: context[:current_user]
      }
    end
  end
end
```

#### フロントエンド実装

**1. Query定義**
```graphql
# src/graphql/queries/session.graphql
query GetCurrentSession {
  currentSession {
    isLoggedIn
    userId
    user {
      id
      name
      avatarUrl
    }
  }
}
```

**2. React実装**
```typescript
import { useGetCurrentSessionQuery } from '@/src/generated/graphql';

export function useSession() {
  const { data, loading, error } = useGetCurrentSessionQuery();

  return {
    session: data?.currentSession,
    isLoading: loading,
    error,
  };
}
```

---

### フェーズ3: 主要機能の移行 (Week 5-8)

#### 優先順位

1. **何切る問題詳細**
   - 問題情報 + 投票結果 + コメント一覧を1リクエストで取得
   - 最も複雑で効果が高い

2. **ユーザープロフィール**
   - ユーザー情報 + フォロー状態 + 投稿一覧を統合

3. **問題一覧**
   - ページネーション + フィルタリング
   - カーソルベースページネーション実装

#### 何切る問題の実装例

**バックエンド**
```ruby
# app/graphql/types/what_to_discard_problem_type.rb
module Types
  class WhatToDiscardProblemType < Types::BaseObject
    field :id, ID, null: false
    field :user, Types::UserType, null: false
    field :tiles, [Types::TileType], null: false
    field :votes_count, Integer, null: false
    field :comments_count, Integer, null: false
    field :likes_count, Integer, null: false

    # ネストしたリソース
    field :vote_results, [Types::VoteResultType], null: false
    field :comments, Types::CommentConnection, null: false
    field :my_vote, Types::VoteType, null: true
    field :is_liked_by_me, Boolean, null: false

    def my_vote
      return nil unless context[:current_user]

      BatchLoader::GraphQL.for(object.id).batch do |problem_ids, loader|
        Vote.where(
          user_id: context[:current_user].id,
          what_to_discard_problem_id: problem_ids
        ).each do |vote|
          loader.call(vote.what_to_discard_problem_id, vote)
        end
      end
    end
  end
end
```

**フロントエンド**
```graphql
query GetWhatToDiscardProblem($id: ID!) {
  whatToDiscardProblem(id: $id) {
    id
    user {
      id
      name
      avatarUrl
      isFollowing
    }
    tiles {
      id
      suit
      ordinalNumberInSuit
      name
    }
    votesCount
    commentsCount
    likesCount
    voteResults {
      tileId
      count
    }
    comments(first: 20) {
      edges {
        node {
          id
          user {
            id
            name
            avatarUrl
          }
          content
          createdAt
          replies(first: 5) {
            edges {
              node {
                id
                content
                user {
                  id
                  name
                }
              }
            }
          }
        }
      }
    }
    myVote {
      id
      tile {
        id
        name
      }
    }
    isLikedByMe
  }
}
```

---

### フェーズ4: Mutation実装 (Week 9-12)

#### フォロー機能の例

**バックエンド**
```ruby
# app/graphql/mutations/follow_user.rb
module Mutations
  class FollowUser < BaseMutation
    argument :user_id, ID, required: true

    field :user, Types::UserType, null: false
    field :errors, [String], null: false

    def resolve(user_id:)
      user = User.find(user_id)
      follow = context[:current_user].active_follows.build(followee: user)

      if follow.save
        { user: user, errors: [] }
      else
        { user: nil, errors: follow.errors.full_messages }
      end
    end
  end
end
```

**フロントエンド**
```graphql
mutation FollowUser($userId: ID!) {
  followUser(input: { userId: $userId }) {
    user {
      id
      isFollowing
    }
    errors
  }
}
```

```typescript
const [followUser] = useFollowUserMutation();

const handleFollow = async () => {
  const { data } = await followUser({
    variables: { userId: user.id },
    update: (cache, { data }) => {
      // Cacheの更新
      cache.modify({
        id: cache.identify(user),
        fields: {
          isFollowing: () => true,
        },
      });
    },
  });
};
```

---

### フェーズ5: リアルタイム機能 (Week 13-14)

#### Subscription実装

**バックエンド**
```ruby
# app/graphql/types/subscription_type.rb
module Types
  class SubscriptionType < GraphQL::Schema::Object
    field :comment_added, Types::CommentType, null: false do
      argument :problem_id, ID, required: true
    end

    def comment_added(problem_id:)
      # Action Cableとの統合
    end
  end
end
```

**フロントエンド**
```graphql
subscription OnCommentAdded($problemId: ID!) {
  commentAdded(problemId: $problemId) {
    id
    content
    user {
      id
      name
    }
    createdAt
  }
}
```

---

## 段階的移行ロードマップ

### Week 1-2: 基盤構築
- [ ] Rails GraphQL gem導入
- [ ] Apollo Client導入
- [ ] GraphQL Code Generator設定
- [ ] 開発環境整備 (GraphiQL)

### Week 3-4: パイロット実装
- [ ] セッション管理のGraphQL化
- [ ] フロントエンドでの動作確認
- [ ] パフォーマンス測定

### Week 5-6: 何切る問題
- [ ] 問題詳細Query実装
- [ ] N+1問題の解決 (graphql-batch)
- [ ] フロントエンド移行
- [ ] A/Bテスト実施

### Week 7-8: ユーザー機能
- [ ] ユーザープロフィールQuery
- [ ] フォロー機能Mutation
- [ ] フロントエンド移行

### Week 9-10: 投票・いいね機能
- [ ] 投票Mutation実装
- [ ] いいねMutation実装
- [ ] 楽観的UI更新

### Week 11-12: コメント機能
- [ ] コメントCRUD Mutation
- [ ] ネストしたコメント (返信) 対応
- [ ] ページネーション実装

### Week 13-14: リアルタイム機能
- [ ] Subscription実装
- [ ] Action Cable統合
- [ ] リアルタイムコメント通知

### Week 15-16: REST API廃止準備
- [ ] 全機能の移行完了確認
- [ ] パフォーマンステスト
- [ ] ドキュメント整備
- [ ] REST APIの段階的廃止

---

## 技術スタック

### バックエンド

```ruby
# Gemfile
gem 'graphql', '~> 2.3'
gem 'graphql-batch' # DataLoaderパターン
gem 'graphiql-rails', group: :development
gem 'apollo_upload_server' # ファイルアップロード
```

### フロントエンド

```json
{
  "dependencies": {
    "@apollo/client": "^3.11.0",
    "graphql": "^16.9.0"
  },
  "devDependencies": {
    "@graphql-codegen/cli": "^5.0.0",
    "@graphql-codegen/typescript": "^4.0.0",
    "@graphql-codegen/typescript-operations": "^4.0.0",
    "@graphql-codegen/typescript-react-apollo": "^4.0.0"
  }
}
```

---

## リスクと対策

### リスク1: 学習コスト

**リスク**: チームのGraphQL経験不足

**対策**:
- パイロット実装で段階的学習
- ペアプログラミング推奨
- 公式ドキュメント・チュートリアル活用

### リスク2: パフォーマンス劣化

**リスク**: N+1問題、複雑なクエリのパフォーマンス

**対策**:
- graphql-batchでDataLoaderパターン実装
- クエリ複雑度制限 (max_depth, max_complexity)
- パフォーマンスモニタリング (Skylight, Scout)

### リスク3: 認証・認可

**リスク**: GraphQL特有の認可実装

**対策**:
- Punditポリシーの再利用
- フィールドレベル認可の実装
- Context経由でcurrent_user注入

### リスク4: キャッシング戦略

**リスク**: REST APIと異なるキャッシュ戦略

**対策**:
- Apollo Clientの正規化キャッシュ活用
- キャッシュキーの適切な設計
- 楽観的UI更新パターンの確立

### リスク5: エラーハンドリング

**リスク**: GraphQLのエラー形式への対応

**対策**:
- カスタムエラーハンドリング実装
- フィールドレベルエラー vs クエリレベルエラーの使い分け
- useErrorToastの拡張

---

## 成功指標 (KPI)

### パフォーマンス
- [ ] API呼び出し回数: 50%削減
- [ ] 初期ロード時間: 30%改善
- [ ] サーバーレスポンスタイム: 20%改善

### 開発効率
- [ ] 新機能開発速度: 40%向上
- [ ] バグ修正時間: 30%短縮
- [ ] APIドキュメント更新コスト: 80%削減

### コード品質
- [ ] 型安全性: 100%カバレッジ
- [ ] テストカバレッジ: 90%以上
- [ ] N+1問題: 0件

---

## 次のステップ

1. **チームレビュー**: この計画をチームで確認・議論
2. **スパイク実装**: Week 1-2の基盤構築を小規模で試す
3. **Go/No-Go判断**: パイロット実装後に本格移行を判断
4. **段階的実行**: ロードマップに沿って段階的に実装

---

## 参考資料

- [GraphQL Ruby公式ドキュメント](https://graphql-ruby.org/)
- [Apollo Client公式ドキュメント](https://www.apollographql.com/docs/react/)
- [GraphQL Code Generator](https://the-guild.dev/graphql/codegen)
- [graphql-batch](https://github.com/Shopify/graphql-batch)