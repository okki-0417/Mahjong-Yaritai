resource "aws_cloudwatch_log_group" "web_task" {
  name              = "/ecs/web-task"
  retention_in_days = 7

  tags = {
    Name = "web-task-log-group"
  }
}
