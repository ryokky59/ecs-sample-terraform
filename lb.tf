// --- ALB ---
resource "aws_lb" "ecs_sample" {
  name                       = "ecs-sample"
  load_balancer_type         = "application" // NLBなら"network"とする
  internal                   = false // ALBがインターネット向けかVPC内部向けか（falseならインターネット向け）
  idle_timeout               = 60
  enable_deletion_protection = false

  subnets = [
    aws_subnet.public_0.id,
    aws_subnet.public_1.id,
  ]

  access_logs {
    bucket  = aws_s3_bucket.alb_log.id
    enabled = true
  }

  security_groups = [
    module.http_sg.security_group_id,
    module.https_sg.security_group_id,
    module.http_redirect_sg.security_group_id,
  ]
}

output "alb_dns_name" {
  value = aws_lb.ecs_sample.dns_name
}

// セキュリティグループ
module "http_sg" {
  source      = "./security_group"
  name        = "http-sg"
  vpc_id      = aws_vpc.ecs_sample.id
  from_port   = 80
  to_port     = 80
  cidr_blocks = ["0.0.0.0/0"]
}

module "https_sg" {
  source      = "./security_group"
  name        = "https-sg"
  vpc_id      = aws_vpc.ecs_sample.id
  from_port   = 443
  to_port     = 443
  cidr_blocks = ["0.0.0.0/0"]
}

module "http_redirect_sg" {
  source      = "./security_group"
  name        = "http-redirect-sg"
  vpc_id      = aws_vpc.ecs_sample.id
  from_port   = 8080
  to_port     = 8080
  cidr_blocks = ["0.0.0.0/0"]
}

// リスナー
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.ecs_sample.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "fixed-response" // 固定のHTTPレスポンスを応答

    fixed_response {
      content_type = "text/plain"
      message_body = "これは『HTTP』です"
      status_code  = "200"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.ecs_sample.arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate.ryokky59.arn
  ssl_policy        = "ELBSecurityPolicy-2016-08"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "これは『HTTPS』です"
      status_code  = "200"
    }
  }
}

resource "aws_lb_listener" "redirect_http_to_https" {
  load_balancer_arn = aws_lb.ecs_sample.arn
  port              = "8080"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener_rule" "ecs_client" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_client.arn
  }

  condition {
    field  = "path-pattern"
    values = ["/*"]
  }
}

resource "aws_lb_listener_rule" "ecs_server" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 99

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_server.arn
  }

  condition {
    field  = "path-pattern"
    values = ["/api/*"]
  }
}

// --- ターゲットグループ ---
resource "aws_lb_target_group" "ecs_client" {
  name                 = "ecs-sample"
  target_type          = "ip" // ECS Fargateはipにする
  vpc_id               = aws_vpc.ecs_sample.id
  port                 = 80
  protocol             = "HTTP"
  deregistration_delay = 300

  health_check {
    path                = "/"
    healthy_threshold   = 5
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    matcher             = 200
    port                = "traffic-port"
    protocol            = "HTTP"
  }

  depends_on = [aws_lb.ecs_sample]
}

resource "aws_lb_target_group" "ecs_server" {
  name                 = "ecs-server"
  target_type          = "ip" // ECS Fargateはipにする
  vpc_id               = aws_vpc.ecs_sample.id
  port                 = 8080
  protocol             = "HTTP"
  deregistration_delay = 300

  health_check {
    path                = "/"
    healthy_threshold   = 5
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    matcher             = 200
    port                = "traffic-port"
    protocol            = "HTTP"
  }

  depends_on = [aws_lb.ecs_sample]
}
