# 麻雀ヤリタイ

1. 環境変数を設定
```
touch ./api/.env
cp ./api/.env.local ./api/.env

touch ./frontend/.env
cp ./frontend/.env.local ./frontend/.env
```

2. Setup
```
docker compose build
docker compose up -d
docker compose exec app bundle exec bin/setup
```
