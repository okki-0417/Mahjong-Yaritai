# ECSクラスター
# サービスを管理する最も上位の論理グループ
resource "aws_ecs_cluster" "web_cluster" {
  name = "web-cluster"
}

# リポジトリを参照
data "aws_ecr_repository" "web_repo" {
  name = "mahjong-yaritai/app"
}

# ECSタスク
# rakeタスクみたいな感じで、再利用可能な一連の処理
resource "aws_ecs_task_definition" "web_task" {
  family                   = "web-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"

  execution_role_arn = aws_iam_role.ecs_execution_role.arn
  task_role_arn      = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "web-container"
      image     = "${data.aws_ecr_repository.web_repo.repository_url}:latest"
      cpu       = 512
      memory    = 1024
      essential = true
      portMappings = [
        {
          containerPort = 3001,
          hostPort      = 3001,
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = "/ecs/web-task",
          awslogs-region        = "ap-northeast-1",
          awslogs-stream-prefix = "web"
        }
      }
      environment = [
        { name = "RAILS_ENV", value = "production" },
        { name = "SECRET_KEY_BASE", value = "68b1ed666748c1a549e173c6a2c811a55719c700fddf6509417a126064435ab923f395c97c997d2746c3fa20ef0aad605a6d37d603c5260f295aee5149c86782" },
        { name = "FRONTEND_DOMAIN", value = "mahjong-yaritai.netlify.app" },

        { name = "HOST_NAME", value = "mahjong-yaritai.com" },
        { name = "REDIS_URL", value = "redis://${aws_elasticache_cluster.redis.cache_nodes[0].address}:6379" },

        { name = "DATABASE_HOST", value = aws_db_instance.rds.address },
        { name = "DATABASE_NAME", value = "app_db" },
        { name = "DATABASE_ROOT", value = "admin" },
        { name = "DATABASE_ROOT_PASSWORD", value = "my_name_is_password" },
      ]
      secrets = [
      ]
    }
  ])
}

# サービス
# タスクの実行を維持・スケーリングしてくれる
# タスク自体は再利用可能なので、同じタスクで複数のサービスを立ち上げてプロダクションやステージングとして使ったりできる
resource "aws_ecs_service" "web_service" {
  name            = "web-service"
  cluster         = aws_ecs_cluster.web_cluster.id
  task_definition = aws_ecs_task_definition.web_task.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.private_1.id, aws_subnet.private_2.id]
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = false
  }

  # ALBのターゲットグループとタスクで立ち上がっているコンテナをつなげてくれる
  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_tg.arn
    container_name   = "web-container"
    container_port   = 3001
  }
}
