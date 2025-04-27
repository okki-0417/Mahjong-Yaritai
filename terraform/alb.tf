# ターゲットグループ
resource "aws_lb_target_group" "web_tg" {
  port        = 80
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.my_vpc.id
  target_type = "ip"

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# ALBを作成
resource "aws_lb" "web_alb" {
  name               = "web-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_sg.id]
  subnets            = ["subnet-0121fe33dfac186a6", "subnet-0596e7ec37a111ddd"]

  enable_deletion_protection = false
}

# ALB用のターゲットグループを作成
resource "aws_lb_target_group" "ecs_tg" {
  name        = "ecs-target-group"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.my_vpc.id
  target_type = "ip" # Fargate は `ip` を指定

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# ターゲットグループのリスナーを作成
# ALB リスナーのデフォルトアクションを ECS に変更
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_tg.arn # ✅ ECS のターゲットグループに変更
  }
}
