# GraphQL移行リファクタリング計画・実施報告

## プロジェクト概要

「麻雀ヤリタイ」プラットフォームにおけるREST APIからGraphQLへの段階的移行を行う。現在はハイブリッド構成（REST + GraphQL）となっているが、機能を損なうことなくGraphQLベースのアーキテクチャへ移行する。

**実施期間**: 2025年1月
**実施状況**: Phase 1・2 部分実装完了

## 現状分析

### 既存のAPI構成

#### REST APIエンドポイント（移行対象）
- 認証関連: `/auth/requests`, `/auth/verifications`, `/sessions` など
- ユーザー管理: `/me/profile`, `/users` など
- 学習機能: `/learnings/categories`, `/learnings/questions` など
- OAuth連携: Google、LINE認証コールバック

#### 既存GraphQL実装
- 何切る問題のCRUD操作
- 投票、いいね、ブックマーク機能
- コメント・返信機能
- フォロー機能
- セッション管理（部分的）

### フロントエンドクライアント構成
- **REST**: Zodios（型安全、自動生成）
- **GraphQL**: Apollo Client（キャッシュ、リアルタイム）
- コードジェネレーション: OpenAPI → Zodios、GraphQL Schema → TypeScript

## 移行戦略

### Phase 1: 認証・セッション管理の完全GraphQL化
**期間**: 1-2週間
**優先度**: 高
**影響範囲**: 全ユーザー操作の基盤

#### 実装タスク
1. **認証ミューテーション実装**
   - `requestAuth`: メール認証リクエスト
   - `verifyAuth`: トークン検証・ログイン
   - `logout`: ログアウト

2. **OAuth統合**
   - GoogleOAuth用ミューテーション
   - LINEOAuth用ミューテーション

3. **セッション管理統一**
   - 既存`currentSession`クエリの拡張
   - リアルタイムセッション状態更新

4. **フロントエンド移行**
   - 認証フォームのGraphQL化
   - セッション管理フックの統一

#### リスク評価
- **高リスク**: ログイン機能の障害
- **対策**: 段階的切り替え、フォールバック機能

### Phase 2: ユーザー管理機能の統一
**期間**: 1週間
**優先度**: 中
**影響範囲**: プロフィール管理、ユーザー情報

#### 実装タスク
1. **プロフィール管理GraphQL化**
   - ファイルアップロード対応（multipart/form-data）
   - 既存`updateUser`ミューテーションの拡張

2. **ユーザー情報クエリ統合**
   - `user`クエリの機能拡張
   - 退会機能（`withdrawUser`）の活用

3. **フロントエンド移行**
   - プロフィール画面のGraphQL化
   - アバター更新機能の移行

#### 技術検討事項
- **ファイルアップロード**: GraphQLでのファイル処理方法
- **解決策**: GraphQL Upload仕様、またはSignedURL方式の採用

### Phase 3: 学習機能のGraphQL化
**期間**: 1週間
**優先度**: 低
**影響範囲**: 学習コンテンツ機能

#### 実装タスク
1. **学習関連クエリ実装**
   - `learningCategories`: カテゴリ一覧
   - `learningQuestions`: カテゴリ別質問一覧
   - `learningQuestion`: 単一質問取得

2. **GraphQL Schema拡張**
   - LearningCategory型の定義済みを確認・活用
   - LearningQuestion型の定義済みを確認・活用

3. **フロントエンド移行**
   - 学習画面のクエリをGraphQL化

### Phase 4: 残存REST APIの整理とGraphQL完全移行
**期間**: 1週間
**優先度**: 中
**影響範囲**: システム全体のAPI統一

#### 実装タスク
1. **API基盤の統一**
   - REST APIルーティングの段階的削除
   - GraphQLエンドポイント単一化

2. **フロントエンドクライアント統一**
   - Zodiosクライアントの段階的廃止
   - Apollo Clientへの完全移行

3. **コードジェネレーション統一**
   - OpenAPI生成処理の停止
   - GraphQL Codegenへの統一

## 技術実装詳細

### GraphQL Schema拡張計画

#### 認証関連の新規ミューテーション
```graphql
extend type Mutation {
  requestAuth(email: String!): RequestAuthPayload!
  verifyAuth(email: String!, token: String!): VerifyAuthPayload!
  logout: LogoutPayload!
  authenticateWithGoogle(authCode: String!): AuthPayload!
  authenticateWithLine(authCode: String!): AuthPayload!
}
```

#### 学習機能の新規クエリ
```graphql
extend type Query {
  learningCategories: [LearningCategory!]!
  learningCategory(id: ID!): LearningCategory
  learningQuestions(learningCategoryId: ID!): [LearningQuestion!]!
  learningQuestion(id: ID!): LearningQuestion
}
```

#### ファイルアップロード対応
```graphql
scalar Upload

extend type Mutation {
  updateUserWithAvatar(
    input: UpdateUserInput!
    avatar: Upload
  ): UpdateUserPayload!
}
```

### フロントエンド移行パターン

#### 段階的移行アプローチ
1. **新規GraphQLクエリ/ミューテーション作成**
2. **既存コンポーネントのGraphQL版作成**
3. **フィーチャーフラグでの段階的切り替え**
4. **RESTクライアントコードの削除**

#### 移行前後の比較例

**移行前（REST）**:
```typescript
// 認証リクエスト
await apiClient.createAuthRequest({ email });

// セッション取得
const { data } = await apiClient.getSession();
```

**移行後（GraphQL）**:
```typescript
// 認証リクエスト
const [requestAuth] = useMutation(RequestAuthDocument);
await requestAuth({ variables: { email } });

// セッション取得
const { data } = useQuery(CurrentSessionDocument);
```

### データベース・バックエンド変更

#### 最小限のバックエンド変更
- GraphQLリゾルバーの追加実装のみ
- 既存のRailsモデル・コントローラーロジックを最大限活用
- データベーススキーマ変更は基本的に不要

#### セキュリティ・認証の継承
- 既存のセッション管理方式を維持
- CSRF、CORS設定の継承
- 既存のバリデーションロジックの活用

## リスク管理とフォールバック計画

### 高リスク項目と対策

1. **認証システム障害**
   - **リスク**: ログイン不能によるサービス停止
   - **対策**: REST API併用期間の設定、緊急時ロールバック計画

2. **ファイルアップロード機能**
   - **リスク**: プロフィール画像更新不能
   - **対策**: GraphQL Upload仕様の事前検証

3. **パフォーマンス劣化**
   - **リスク**: N+1クエリ、レスポンス遅延
   - **対策**: DataLoader活用、キャッシュ戦略最適化

### フォールバック戦略
1. **段階的切り替え**: フィーチャーフラグによる機能別移行
2. **ロールバック準備**: 各Phase完了時点でのロールバック計画
3. **監視強化**: エラー率、レスポンス時間の継続監視

## 移行完了後のメリット

### 開発効率の向上
1. **API統一**: 単一のGraphQLエンドポイント
2. **型安全性**: 自動生成されたTypeScript型の完全活用
3. **キャッシュ効率**: Apollo Clientによる最適なキャッシュ戦略

### 運用・保守の改善
1. **ドキュメント自動生成**: GraphQL Schemaからの自動ドキュメント
2. **デバッグ効率**: GraphQL Playgroundによる開発支援
3. **バージョニング**: Schema進化による後方互換性

### パフォーマンス最適化
1. **必要データのみ取得**: GraphQLクエリによる最適化
2. **バッチ処理**: DataLoaderによるN+1問題解決
3. **リアルタイム更新**: Subscriptionによるリアルタイム機能

## 実施スケジュール

| Phase | 期間 | 主要マイルストーン |
|-------|------|-------------------|
| Phase 1 | 2週間 | 認証GraphQL化完了 |
| Phase 2 | 1週間 | ユーザー管理統一完了 |
| Phase 3 | 1週間 | 学習機能GraphQL化完了 |
| Phase 4 | 1週間 | REST API完全廃止 |

**合計期間**: 5週間
**完了予定**: 移行開始から約1.5ヶ月後

## 成功基準

### 機能要件
- [ ] 全機能が移行前と同等に動作
- [ ] レスポンス時間が移行前と同等以上
- [ ] エラー率が移行前と同等以下

### 非機能要件
- [ ] TypeScript型安全性の完全確保
- [ ] APIエンドポイントの単一化
- [ ] 開発者体験の向上（DX）

### 運用要件
- [ ] 監視・ログ体制の継続
- [ ] デプロイメントプロセスの維持
- [ ] ドキュメントの最新化

この移行計画により、機能を損なうことなく、より保守性が高く、開発効率の良いGraphQLベースのアーキテクチャへの移行を実現する。

---

## 実施結果報告（2025年1月）

### 📊 GraphQL移行状況サマリー

| 機能領域 | 移行状況 | 備考 |
|---------|---------|------|
| **認証・セッション管理** | ❌ REST継続 | 実装困難性により継続使用 |
| **ユーザー管理（プロフィール編集）** | ✅ GraphQL完了 | ファイルアップロード対応済み |
| **何切る問題関連** | ✅ GraphQL完了 | 移行前から実装済み |
| **学習機能** | ⏸️ 開発停止 | ユーザー要請により保留 |
| **OAuth連携** | ❌ REST継続 | 外部API連携の複雑性 |

### ✅ **GraphQLに移行完了した機能**

#### 1. ユーザー管理（プロフィール編集）
- **実装ファイル**:
  - `app/graphql/mutations/update_user.rb` - プロフィール更新
  - `app/graphql/types/upload_type.rb` - ファイルアップロード対応
  - `src/app/me/profile/ProfileEditFormGraphQL.tsx` - フロントエンド
  - `src/lib/graphqlFileUpload.ts` - ファイルアップロードライブラリ
- **特徴**: カスタムUploadType使用でアバター画像アップロード対応
- **メリット**: 統一されたGraphQLインターフェース、型安全性

#### 2. 何切る問題関連（移行前から完了）
- **範囲**: CRUD操作、投票、いいね、ブックマーク、コメント、フォロー機能
- **状況**: 既にGraphQLで実装済み、REST APIは存在しない

### ❌ **RESTで継続使用中の機能と理由**

#### 1. 認証・セッション管理
**継続使用中のエンドポイント**:
- `POST /auth/request` - メール認証要求
- `POST /auth/verification` - トークン検証
- `GET|DELETE /session` - セッション管理

**RESTを継続する理由**:
1. **実装複雑性**: GraphQL認証フローはREST版より大幅に複雑
2. **Apollo Client依存**: 適切なReact hooksの統合が困難
3. **フロントエンド実装負担**: 認証フォームの書き換えコストが高い
4. **動作実績**: 既存REST版は安定動作しており、リスクが低い
5. **優先度**: プロフィール管理移行の方が価値が高い

**技術的課題**:
- `useMutation`、`useApolloClient`の適切な統合
- RelayClassicMutationのInput objectパターンの複雑性
- エラーハンドリングとトースト通知の統合

#### 2. OAuth連携（Google・LINE）
**継続使用中のエンドポイント**:
- `GET /auth/google/login` - Googleログインページ
- `POST /auth/google/callback` - Googleコールバック
- `GET /auth/line/login_url` - LINEログインURL取得
- `POST /auth/line/callback` - LINEコールバック

**RESTを継続する理由**:
1. **外部API連携**: OAuth プロバイダーとの統合が複雑
2. **リダイレクト処理**: ブラウザリダイレクトベースの認証フロー
3. **セキュリティ**: 実績のあるOAuth実装を維持
4. **投資対効果**: GraphQL化の恩恵が少ない

#### 3. 学習機能
**継続使用中のエンドポイント**:
- `GET /learnings/categories` - カテゴリ一覧
- `GET /learnings/categories/:id/questions` - 問題一覧

**RESTを継続する理由**:
1. **開発停止**: ユーザー要請により機能開発を停止
2. **移行優先度低**: 使用頻度が低い機能
3. **リソース制約**: 他機能の移行を優先

**注意事項**:
- GraphQLクエリは既に実装済み（`learning_categories`, `learning_questions`）
- GraphQLスキーマ定義済み（`LearningCategoryType`, `LearningQuestionType`）
- フロントエンドのみREST使用中、必要に応じて簡単に移行可能
- コントローラー・REST APIは保持（将来的な開発再開に備える）

### 🔧 実装された技術要素

#### GraphQLファイルアップロード実装
```typescript
// カスタムUploadType（API側）
class UploadType < GraphQL::Schema::Scalar
  def self.coerce_input(input, context)
    if input.is_a?(ActionDispatch::Http::UploadedFile)
      input
    else
      raise GraphQL::CoercionError, "Expected uploaded file"
    end
  end
end

// フロントエンド統合
export async function updateUserWithFile(client, input) {
  // multipart/form-data でGraphQLリクエスト送信
}
```

#### 型安全なフォーム統合
- Zod スキーマバリデーション
- React Hook Form統合
- Apollo Client基本実装（useApolloClientは使用せず）

### 📈 移行の成果

#### ✅ 成功要因
1. **段階的移行**: プロフィール機能のみに集中
2. **ファイルアップロード解決**: GraphQLでの課題を技術的に解決
3. **型安全性**: TypeScript型チェック全て通過
4. **既存機能維持**: REST認証継続により安定性確保

#### ⚠️ 課題・制約
1. **ハイブリッド構成**: REST + GraphQLの並存
2. **Apollo Client統合不完全**: React hooks の活用が限定的
3. **認証GraphQL未実装**: 一定の技術的複雑性が残存

### 🎯 今後の方針

#### 短期（1-3ヶ月）
- 現在のハイブリッド構成を維持
- プロフィール管理GraphQL版の動作検証・最適化
- REST認証の継続使用

#### 中期（3-6ヶ月）
- Apollo Client の適切な統合研究
- 認証GraphQL化の再検討（技術的困難の解決）
- 学習機能の開発再開時にGraphQL実装

#### 長期（6ヶ月以上）
- 完全GraphQL化の再評価
- REST API段階的廃止の検討

### 🚀 次のフェーズ候補

#### Phase 3A: Apollo Client統合改善
**目的**: GraphQLの活用度向上
**内容**:
- React hooks（`useMutation`, `useQuery`, `useApolloClient`）の適切な統合
- Apollo Client Provider の設定改善
- キャッシュ戦略の最適化
- 既存GraphQL機能の活用度向上

**メリット**:
- より標準的なGraphQL実装パターン
- 開発者体験の向上
- リアルタイム機能の準備

**技術課題**:
- Apollo Client 4.x の適切な設定方法の調査
- Next.js 15 との統合方法
- 既存実装との互換性維持

#### Phase 3B: 認証GraphQL化の技術課題解決
**目的**: 認証機能のGraphQL移行
**内容**:
- Apollo Client React hooks統合の課題解決
- 認証フローのUX改善
- エラーハンドリングの統一

**メリット**:
- API統一によるメンテナンス性向上
- GraphQLの型安全性活用
- 開発パターンの統一

**技術課題**:
- `useMutation` の適切な実装パターン確立
- 認証状態管理とApollo Clientの統合
- 複雑性とメリットのバランス

#### Phase 3C: 学習機能GraphQL移行（開発再開時）
**目的**: 将来の開発再開に備えた準備
**内容**:
- 既存GraphQLクエリの活用
- フロントエンド簡易移行
- REST API段階的削除

**現状**: 開発停止中のため優先度低

**準備状況**:
- GraphQL実装完了済み
- 移行コストは最小限

### 💡 教訓

1. **技術選択**: 複雑性とメリットのバランスを慎重に評価
2. **段階的移行**: 全体移行よりも価値の高い部分的移行が実用的
3. **実装困難性**: Apollo Client React hooksの統合は予想以上に複雑
4. **ファイルアップロード**: GraphQLでも実現可能だが、独自実装が必要

この部分移行により、最も価値の高いプロフィール管理機能のGraphQL化を実現し、認証などの基盤機能は安定性を優先して既存RESTを維持する、実用的なアーキテクチャを確立した。