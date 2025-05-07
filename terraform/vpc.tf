# VPCをタグで検索して参照
data "aws_vpc" "my_vpc" {
  filter {
    name   = "tag:Name"
    values = ["Mahjong-Yaritai"]
  }
}

# インターネットゲートウェイ
data "aws_internet_gateway" "my_i_gw" {
  filter {
    name   = "tag:Name"
    values = ["Mahjong-Yaritai"]
  }
}

# ElasticIP
resource "aws_eip" "nat_eip" {
  tags = {
    Name = "nat-gateway-eip"
  }
}

# NATゲートウェイ用のパブリックサブネット
resource "aws_subnet" "public_1" {
  vpc_id                  = data.aws_vpc.my_vpc.id
  cidr_block              = "10.0.30.0/24"
  availability_zone       = "ap-northeast-1a"
  map_public_ip_on_launch = true # これが true だとEC2などに自動でパブリックIPが割り当てられます

  tags = {
    Name = "public-1"
  }
}

# NATゲートウェイ
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_1.id

  tags = {
    Name = "main-nat-gateway"
  }
}

# NATゲートウェイのパブリックサブネット用のルートテーブル
resource "aws_route_table" "public_rt" {
  vpc_id = data.aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = data.aws_internet_gateway.my_i_gw.id
  }

  tags = {
    Name = "public-rt"
  }
}

# ルートテーブルとNATゲートウェイ用のパブリックサブネットを関連付け
resource "aws_route_table_association" "public_1_assoc" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public_rt.id
}

# ECS用のプライベートサブネット用のルートテーブル
resource "aws_route_table" "private_rt" {
  vpc_id = data.aws_vpc.my_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "private-rt"
  }
}

# ルートテーブルをECS用のプライベートサブネット1に関連付け
resource "aws_route_table_association" "private_1_assoc" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private_rt.id
}

# ルートテーブルをECS用のプライベートサブネット2に関連付け
resource "aws_route_table_association" "private_2_assoc" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private_rt.id
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
