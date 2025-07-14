# シークレットを参照
data "aws_secretsmanager_secret" "rds_password" {
  name = "prod/Mahjong-Yaritai/RDS"
}

# 最新のシークレットの値（バージョン）を取得
data "aws_secretsmanager_secret_version" "rds_password_version" {
  secret_id = data.aws_secretsmanager_secret.rds_password.id
}

# RDSを作成
resource "aws_db_instance" "rds" {
  allocated_storage       = 20
  storage_type            = "gp2"
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = "db.t3.micro" # AWS 無料枠の最小サイズ
  identifier              = "mydatabase"
  username                = "admin"
  password                = "my_name_is_password"
  parameter_group_name    = "default.mysql8.0"
  publicly_accessible     = false
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]
  db_subnet_group_name    = aws_db_subnet_group.main.name
  skip_final_snapshot     = true # データベース削除時にスナップショットを取らない
  backup_retention_period = 7    # 7日間の自動バックアップ
}
