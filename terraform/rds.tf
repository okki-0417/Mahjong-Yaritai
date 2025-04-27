# RDSを作成
resource "aws_db_instance" "rds" {
  allocated_storage       = 20
  storage_type            = "gp2"
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = "db.t3.micro" # AWS 無料枠の最小サイズ
  identifier              = "mydatabase"
  username                = "admin"
  password                = "your-secure-password" # セキュアなパスワードを設定（Secrets Manager に移行推奨）
  parameter_group_name    = "default.mysql8.0"
  publicly_accessible     = false
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]
  db_subnet_group_name    = aws_db_subnet_group.main.name
  skip_final_snapshot     = true # データベース削除時にスナップショットを取らない
  backup_retention_period = 7    # 7日間の自動バックアップ
}
