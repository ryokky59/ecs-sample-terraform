resource "aws_cloudwatch_log_group" "for_ecs_client" {
  name              = "/ecs/client"
  retention_in_days = 180
}

resource "aws_cloudwatch_log_group" "for_ecs_server" {
  name              = "/ecs/server"
  retention_in_days = 180
}
