# Mahjong Yaritai

## 1. Clone Submodules

```bash
git submodule update --init
```

## 2. Set Up Environment Variables

```bash
touch ./api/.env
cp ./api/.env.local ./api/.env

touch ./frontend/.env
cp ./frontend/.env.local ./frontend/.env
```

## 3. Create API Log Files

```bash
mkdir -p ./api/log
touch ./api/log/development.log
touch ./api/spec/log.txt
```

## 4. Bring Up the Docker Environment

```bash
docker compose up -d
```

## 5. Set Up the API

```bash
docker compose exec app bundle exec bin/setup
```

## 6. Set Up the Frontend

```bash
cd frontend
npm install
npm run dev
```
