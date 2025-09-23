# CLAUDE.md

このファイルは、Claude Code (claude.ai/code) がこのリポジトリで作業する際のガイダンスを提供します。

## プロジェクト概要

「麻雀ヤリタイ」- 麻雀の「何切る問題」に特化したコミュニティプラットフォームです。ユーザーは麻雀の手牌を分析し、どの牌を切るべきかを投票・議論できます。

## プロジェクト構成

- **api/**: Rails 7.2.1 APIアプリケーション（詳細は `api/CLAUDE.md` を参照）
- **frontend/**: Next.js 15 フロントエンドアプリケーション（詳細は `frontend/CLAUDE.md` を参照）
- **terraform/**: インフラ構成コード

## クイックスタート

```bash
# 1. サブモジュールのクローン
git submodule update --init

# 2. 環境変数の設定
touch ./api/.env && cp ./api/.env.local ./api/.env
touch ./frontend/.env && cp ./frontend/.env.local ./frontend/.env

# 3. APIログファイルの作成
mkdir -p ./api/log
touch ./api/log/development.log ./api/spec/log.txt

# 4. Docker環境の起動
docker compose up -d

# 5. APIのセットアップ
docker compose exec app bundle exec bin/setup

# 6. フロントエンドのセットアップと起動
cd frontend
npm install
npm run dev
```

## システム全体アーキテクチャ

### マイクロサービス構成
- **APIサーバー**: Rails API (ポート3001) - 全てのビジネスロジックとデータ管理
- **フロントエンド**: Next.js (ポート3000) - ユーザーインターフェース
- **データベース**: PostgreSQL - メインデータストア
- **キャッシュ/セッション**: Redis - セッション管理とジョブキュー
- **バックグラウンド処理**: Sidekiq - 非同期ジョブ処理

### 主要機能

1. **何切る問題 (What to Discard Problems)**
   - 麻雀の手牌（13枚）とツモ牌（1枚）から何を切るかを問う
   - ユーザー投票システム
   - コメント・いいね機能

2. **認証システム**
   - パスワードレス認証（メールでの6桁トークン）
   - セッションベース（Redis使用）
   - Google OAuth対応（フロントエンド側）

3. **ユーザー機能**
   - プロフィール管理
   - アバター画像（ActiveStorage）
   - 退会処理

## 開発フロー

### 機能追加時の流れ
1. APIでモデル・コントローラー実装
2. RSpecでテスト作成
3. API仕様書生成（Swagger）
4. フロントエンドでAPIクライアント再生成
5. UIコンポーネント実装

### ブランチ戦略
- `main`: 本番環境
- 機能ブランチから `main` へのPR

## Docker環境

```yaml
services:
  db: PostgreSQL データベース
  app: Rails APIサーバー
  sidekiq: バックグラウンドワーカー
  redis: キャッシュ・セッション管理
```

## 環境間の違い

### 開発環境
- ローカルファイルストレージ
- letter_opener_webでメール確認
- Docker Compose環境

### 本番環境
- AWS S3ファイルストレージ
- SMTP経由でのメール送信
- Sentryエラー監視

## トラブルシューティング

### よくある問題
1. **Docker環境が起動しない**: `docker compose down -v` で完全リセット
2. **APIとフロントエンドの型不一致**: `npm run gen-client` でクライアント再生成
3. **セッション問題**: Redisの再起動 `docker compose restart redis`

## 重要な注意事項

- **API仕様変更時**: 必ずフロントエンドのAPIクライアントを再生成する
- **データベース変更時**: マイグレーション後、フロントエンドの型定義も確認
- **環境変数**: `.env.local` ファイルをテンプレートとして使用

## 開発時のクイックリファレンス

### よく使うコマンド一覧
```bash
# Docker環境
docker compose up -d                     # サービス起動
docker compose restart [service]         # 特定サービス再起動
docker compose logs -f [service]         # ログ表示

# Rails開発
docker compose exec app bundle exec rails c     # コンソール
docker compose exec app bundle exec rspec       # テスト実行
docker compose exec app bundle exec rails rswag:specs:swaggerize  # API仕様生成

# フロントエンド開発
cd frontend && npm run dev               # 開発サーバー
cd frontend && npm run gen-client        # APIクライアント再生成
cd frontend && npm run typecheck         # 型チェック
```

### デバッグTips
- **APIレスポンス確認**: Swagger UI (`http://localhost:3001/api-docs`)
- **メール確認**: letter_opener_web (`http://localhost:3001/letter_opener`)
- **Redisセッション確認**: `docker compose exec app bundle exec rails c` → `Redis.new.keys`
- to memorize
