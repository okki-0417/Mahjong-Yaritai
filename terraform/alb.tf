# リスナー
# どのアクセスをどのターゲットグループに繋げるかの判断ルール
# ALBはこのルールを参照してそれ通りにやるだけの土台的なもの
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "forward"
    # ECS のターゲットグループ
    target_group_arn = aws_lb_target_group.ecs_tg.arn
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "arn:aws:acm:ap-northeast-1:180294178005:certificate/e85f07df-9e0b-44f4-8998-e9fa0802f23b"

  default_action {
    type = "forward"
    # ECS のターゲットグループ
    target_group_arn = aws_lb_target_group.ecs_tg.arn
  }
}

# ターゲットグループ
# ALBは直接ECSやEC2に繋げることはせず、ターゲットグループという抽象的な存在に繋げる
# これによってALBは繋げる先について知らなくても良いので、責務が分散し・柔軟性が向上する
resource "aws_lb_target_group" "ecs_tg" {
  name     = "ecs-target-group"
  port     = 3001
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.my_vpc.id
  # Fargate は ip を指定
  target_type = "ip"

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# ALB
resource "aws_lb" "web_alb" {
  name               = "web-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_sg.id]
  subnets            = ["subnet-0121fe33dfac186a6", "subnet-0596e7ec37a111ddd"]

  enable_deletion_protection = false
}
