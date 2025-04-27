# ElastiCache (Redis) の作成
resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "my-redis-cluster"
  engine               = "redis"
  node_type            = "cache.t4g.micro" # AWS 無料枠を使用する場合は `cache.t4g.micro`
  num_cache_nodes      = 1                 # シングルノード構成
  parameter_group_name = "default.redis7"
  engine_version       = "7.0"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.redis_subnet_group.name
  security_group_ids   = [aws_security_group.redis_sg.id]

  tags = {
    Name = "MyRedisCluster"
  }
}
