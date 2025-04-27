# 麻雀ヤリタイ

1. APIとフロントエンドを個別にGit管理しているため、サブモジュールとしてクローンする必要がある
```
git submodule update --init --recursive
```

2. 環境変数を設定
```
touch ./api/.env
cp ./api/.env.local ./api/.env

touch ./frontend/.env
cp ./frontend/.env.local ./frontend/.env
```

3. ログファイルを作成
```
mkdir ./api/log
touch ./api/log/development.log
```

3. セットアップ
```
docker compose up
docker compose exec app bundle exec bin/setup
```
