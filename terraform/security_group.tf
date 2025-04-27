# ALB 用のセキュリティグループ
resource "aws_security_group" "web_sg" {
  name        = "web-security-group"
  description = "Allow HTTP/HTTPS traffic for ALB"
  vpc_id      = data.aws_vpc.my_vpc.id

  # HTTP (80) 許可
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # すべての IP から許可
  }

  # HTTPS (443) 許可
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # すべての IP から許可
  }

  # アウトバウンド通信をすべて許可
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"          # 全てのプロトコル
    cidr_blocks = ["0.0.0.0/0"] # すべての IP から許可
  }
}


# ECSのセキュリティグループ
resource "aws_security_group" "ecs_sg" {
  description = "Allow HTTP/HTTPS traffic for ECS"
  vpc_id      = data.aws_vpc.my_vpc.id

  ingress {
    from_port       = 80
    to_port         = 3001
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  ingress {
    from_port       = 443
    to_port         = 3001
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# RDSのセキュリティグループ
resource "aws_security_group" "rds_sg" {
  name        = "rds-security-group"
  description = "Allow RDS access to "
  vpc_id      = data.aws_vpc.my_vpc.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_sg.id] # ✅ ECS からのアクセスを許可
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ElastiCache 用のセキュリティグループ
resource "aws_security_group" "redis_sg" {
  name        = "redis-security-group"
  description = "Allow ECS access to Redis"
  vpc_id      = data.aws_vpc.my_vpc.id

  # ECS からの接続を許可
  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_sg.id] # ✅ ECS からのアクセスを許可
  }

  # すべてのアウトバウンドトラフィックを許可
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
