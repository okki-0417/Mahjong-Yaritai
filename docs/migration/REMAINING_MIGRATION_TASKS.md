# 残りのGraphQL移行タスク

## 概要
現在、主要なMutation機能（投票、いいね、コメント、フォロー）のGraphQL移行が完了しました。
残りのREST API呼び出しをGraphQLに移行することで、パフォーマンスの向上と統一されたデータフェッチングを実現します。

## 優先度高: Query移行（読み取り系）

### 1. 投票結果取得の統合
**対象コンポーネント**:
- `VoteButton.tsx` (3箇所)
- `ProblemVoteSection.tsx` (1箇所)

**現状**: 投票後にREST APIで結果を取得
```typescript
const voteResultResponse = await apiClient.getWhatToDiscardProblemVoteResult({
  params: { what_to_discard_problem_id: String(problem.id) }
});
```

**改善案**: GraphQL Queryで問題詳細と投票結果を一度に取得
```graphql
query WhatToDiscardProblemWithVotes($id: ID!) {
  whatToDiscardProblem(id: $id) {
    id
    voteResults {
      tileId
      count
      percentage
    }
  }
}
```

### 2. いいね状態の統合
**対象コンポーネント**:
- `ProblemLikeSection.tsx`

**現状**: 別途REST APIでいいね状態を取得
```typescript
const response = await apiClient.getWhatToDiscardProblemMyLike({
  params: { what_to_discard_problem_id: String(problem.id) }
});
```

**改善案**: 問題詳細クエリに含める
```graphql
type WhatToDiscardProblemType {
  # 既存フィールド
  isLikedByMe: Boolean!
  myVote: WhatToDiscardProblemVoteType
}
```

### 3. コメント取得の統合
**対象コンポーネント**:
- `ProblemCommentSection.tsx`
- `FetchRepliesButton.tsx`

**改善案**: GraphQL Queryでコメントと返信を効率的に取得
```graphql
query WhatToDiscardProblemComments($problemId: ID!, $cursor: String, $limit: Int) {
  whatToDiscardProblemComments(problemId: $problemId, cursor: $cursor, limit: $limit) {
    edges {
      node {
        id
        content
        replies(first: 5) {
          edges {
            node {
              id
              content
            }
          }
        }
      }
    }
    pageInfo {
      hasNextPage
      endCursor
    }
  }
}
```

## 優先度中: Mutation移行（書き込み系）

### 4. 問題作成・更新のGraphQL化
**対象コンポーネント**:
- `ProblemCreateForm.tsx`
- `ProblemUpdateForm.tsx`

**必要なMutation**:
```graphql
mutation CreateWhatToDiscardProblem($input: CreateWhatToDiscardProblemInput!) {
  createWhatToDiscardProblem(input: $input) {
    whatToDiscardProblem {
      id
      title
      description
      tiles {
        id
        imageUrl
      }
    }
    errors
  }
}

mutation UpdateWhatToDiscardProblem($id: ID!, $input: UpdateWhatToDiscardProblemInput!) {
  updateWhatToDiscardProblem(id: $id, input: $input) {
    whatToDiscardProblem {
      id
      title
      description
    }
    errors
  }
}
```

### 5. ページング処理の最適化
**対象コンポーネント**:
- `LoadNextPageProblemButton.tsx`

**改善案**: GraphQLのConnection仕様に統一
```graphql
query WhatToDiscardProblems($after: String, $first: Int) {
  whatToDiscardProblems(after: $after, first: $first) {
    edges {
      cursor
      node {
        id
        title
      }
    }
    pageInfo {
      hasNextPage
      endCursor
    }
  }
}
```

## パフォーマンス改善の期待値

### 現在のAPI呼び出し数（問題詳細ページ）
1. 問題詳細取得: `GET /what_to_discard_problems/:id`
2. いいね状態取得: `GET /what_to_discard_problems/:id/my_like`
3. 投票状態取得: `GET /what_to_discard_problems/:id/my_vote`
4. 投票結果取得: `GET /what_to_discard_problems/:id/vote_result`
5. コメント取得: `GET /what_to_discard_problems/:id/comments`

**合計**: 5回のAPI呼び出し

### GraphQL移行後
```graphql
query WhatToDiscardProblemDetail($id: ID!) {
  whatToDiscardProblem(id: $id) {
    id
    title
    description
    tiles { ... }
    isLikedByMe
    likesCount
    myVote { ... }
    voteResults { ... }
    votesCount
    comments(first: 10) { ... }
    commentsCount
  }
}
```

**合計**: 1回のAPI呼び出し

**削減率**: 80% (5回 → 1回)

## 実装ステップ

### Phase 1: バックエンドQuery/Mutation追加（1-2日）
- [ ] 問題作成Mutation
- [ ] 問題更新Mutation
- [ ] 投票結果をWhatToDiscardProblemTypeに統合
- [ ] コメント取得Query

### Phase 2: フロントエンド移行（2-3日）
- [ ] GraphQLドキュメント作成
- [ ] 型生成とhooks実装
- [ ] コンポーネント更新
- [ ] テスト実施

### Phase 3: パフォーマンス検証（1日）
- [ ] 開発環境でのベンチマーク
- [ ] ネットワーク呼び出し数の測定
- [ ] レスポンス時間の比較

### Phase 4: 本番移行（1日）
- [ ] 段階的ロールアウト
- [ ] モニタリング
- [ ] REST APIの段階的廃止

## リスクと対策

### リスク1: キャッシュ戦略の変更
**対策**: Apollo Clientのキャッシュポリシーを適切に設定

### リスク2: エラーハンドリングの統一
**対策**: GraphQLエラーとネットワークエラーの適切な分離

### リスク3: 既存機能への影響
**対策**: Feature Flagによる段階的移行

## 成功指標

1. **パフォーマンス**
   - API呼び出し数: 50%以上削減
   - ページロード時間: 30%改善

2. **開発効率**
   - 型安全性の向上
   - データフェッチングの簡素化

3. **保守性**
   - 統一されたデータフェッチング層
   - REST APIの完全廃止

## 次のアクション

1. バックエンドチームと実装優先度の調整
2. Phase 1のMutation実装開始
3. フロントエンドのGraphQLドキュメント準備