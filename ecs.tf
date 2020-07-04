// --- クラスター ---
resource "aws_ecs_cluster" "ecs_sample" {
  name = "ecs-sample"
}

// --- タスク定義 ---
resource "aws_ecs_task_definition" "ecs_client" {
  family                   = "ecs-client"
  cpu                      = "256"
  memory                   = "512"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  container_definitions    = file("./container_definitions/client.json")
  task_role_arn            = module.ecs_task_execution_role.iam_role_arn
  execution_role_arn       = module.ecs_task_execution_role.iam_role_arn
}

resource "aws_ecs_task_definition" "ecs_server" {
  family                   = "ecs-server"
  cpu                      = "256"
  memory                   = "512"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  container_definitions    = file("./container_definitions/server.json")
  task_role_arn            = module.ecs_task_execution_role.iam_role_arn
  execution_role_arn       = module.ecs_task_execution_role.iam_role_arn
}

// --- サービス ---
resource "aws_ecs_service" "ecs_client" {
  name                              = "ecs-client"
  cluster                           = aws_ecs_cluster.ecs_sample.arn
  task_definition                   = aws_ecs_task_definition.ecs_client.arn
  desired_count                     = 1 // 開発中は1にしておくと料金に無駄がなくなる
  launch_type                       = "FARGATE"
  platform_version                  = "1.3.0"
  health_check_grace_period_seconds = 60

  network_configuration {
    assign_public_ip = false
    security_groups  = [module.client_sg.security_group_id]

    subnets = [
      aws_subnet.private_0.id,
      aws_subnet.private_1.id,
    ]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_client.arn
    container_name   = "sample-client"
    container_port   = 3000
  }

  lifecycle {
    ignore_changes = [task_definition]
  }
}

module "client_sg" {
  source      = "./security_group"
  name        = "client-sg"
  vpc_id      = aws_vpc.ecs_sample.id
  from_port   = 80
  to_port     = 3000
  cidr_blocks = [aws_vpc.ecs_sample.cidr_block]
}

resource "aws_ecs_service" "ecs_server" {
  name                              = "ecs-sgserver"
  cluster                           = aws_ecs_cluster.ecs_sample.arn
  task_definition                   = aws_ecs_task_definition.ecs_server.arn
  desired_count                     = 1 // 開発中は1にしておくと料金に無駄がなくなる
  launch_type                       = "FARGATE"
  platform_version                  = "1.3.0"
  health_check_grace_period_seconds = 60

  network_configuration {
    assign_public_ip = false
    security_groups  = [module.server_sg.security_group_id]

    subnets = [
      aws_subnet.private_0.id,
      aws_subnet.private_1.id,
    ]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_server.arn
    container_name   = "sample-server"
    container_port   = 8080
  }

  lifecycle {
    ignore_changes = [task_definition]
  }
}

module "server_sg" {
  source      = "./security_group"
  name        = "server-sg"
  vpc_id      = aws_vpc.ecs_sample.id
  from_port   = 8080
  to_port     = 8080
  cidr_blocks = [aws_vpc.ecs_sample.cidr_block]
}
