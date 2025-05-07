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
        { name = "FRONTEND_DOMAIN", value = "mahjong-yaritai.netlify.app" },

        { name = "HOST_NAME", value = "mahjong-yaritai.com" },
        { name = "REDIS_URL", value = aws_elasticache_cluster.redis.cache_nodes[0].address },

        { name = "DATABASE_HOST", value = aws_db_instance.rds.address },
        { name = "DATABASE_NAME", value = "database" },
        { name = "DATABASE_ROOT", value = "app_user" },
      ]
      secrets = [
        { name = "DATABASE_ROOT_PASSWORD", valueFrom = data.aws_secretsmanager_secret.rds_password.arn },
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
