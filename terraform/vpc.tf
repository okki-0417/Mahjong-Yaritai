# VPCをタグで検索して参照
data "aws_vpc" "my_vpc" {
  filter {
    name   = "tag:Name"
    values = ["Mahjong-Yaritai"]
  }
}

# ECSを置く用のプライベートサブネット1
resource "aws_subnet" "private_1" {
  vpc_id                  = data.aws_vpc.my_vpc.id
  cidr_block              = "10.0.20.0/24"
  availability_zone       = "ap-northeast-1a"
  map_public_ip_on_launch = false
}

# ECSを置く用のプライベートサブネット2
resource "aws_subnet" "private_2" {
  vpc_id                  = data.aws_vpc.my_vpc.id
  cidr_block              = "10.0.21.0/24"
  availability_zone       = "ap-northeast-1c"
  map_public_ip_on_launch = false
}

# ElastiCache 用のサブネットグループ
resource "aws_elasticache_subnet_group" "redis_subnet_group" {
  name       = "redis-subnet-group"
  subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id]

  tags = {
    Name = "RedisSubnetGroup"
  }
}

# RDS用のサブネットグループ
resource "aws_db_subnet_group" "main" {
  name       = "main-db-subnet-group"
  subnet_ids = ["subnet-0e3fcf0658580244f", "subnet-05f582cb5d54dea7b"]

  tags = {
    Name = "MainDBSubnetGroup"
  }
}
