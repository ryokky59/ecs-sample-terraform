// --- ポリシー ---
data "aws_iam_policy_document" "allow_describe_regions" {
  statement {
    effect    = "Allow"
    actions   = ["ec2:DescribeRegions"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "ecs_sample" {
  name   = "ecs-sample"
  policy = data.aws_iam_policy_document.allow_describe_regions.json
}

// --- ロール ---
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_sample" {
  name               = "ecs-sample"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

// ポリシーとロールのアタッチ
resource "aws_iam_role_policy_attachment" "ecs_sample" {
  role       = aws_iam_role.ecs_sample.name
  policy_arn = aws_iam_policy.ecs_sample.arn
}

// --- ECS用のIAM ---
data "aws_iam_policy" "ecs_task_execution_role_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "ecs_task_execution" {
  source_json = data.aws_iam_policy.ecs_task_execution_role_policy.policy

  statement {
    effect    = "Allow"
    actions   = ["ssm:GetParameters", "kms:Decrypt"]
    resources = ["*"]
  }
}

module "ecs_task_execution_role" {
  source     = "./iam_role"
  name       = "ecs-task-execution"
  identifier = "ecs-tasks.amazonaws.com"
  policy     = data.aws_iam_policy_document.ecs_task_execution.json
}
