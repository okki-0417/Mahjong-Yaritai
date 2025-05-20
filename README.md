# 麻雀ヤリタイ

## クローン
**APIとフロントエンドを個別にGit管理しているため、サブモジュールとしてクローンする必要がある**
```
git submodule update --init --recursive
```

## セットアップ
### 環境変数
```
touch ./api/.env
cp ./api/.env.local ./api/.env

touch ./frontend/.env
cp ./frontend/.env.local ./frontend/.env
```

### ログファイルを作成
**Railsを立ち上げるのに必要**
```
mkdir ./api/log
touch ./api/log/development.log
touch ./api/spec/log.txt
```

## 立ち上げる
### バックエンド（Rails API）
```
docker compose up -d
```

#### DB作成やSeedのセットアップ
```
docker compose exec app bundle exec bin/setup
```

### フロントエンド（Next.js）
```
cd frontend
npm install
npm run dev
```
