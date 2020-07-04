// --- VPC ---
resource "aws_vpc" "ecs_sample" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "ecs-sample"
  }
}

// --- パブリックサブネット ---
resource "aws_subnet" "public_0" {
  vpc_id                  = aws_vpc.ecs_sample.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-northeast-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.ecs_sample.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-northeast-1c"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "ecs_sample" {
  vpc_id = aws_vpc.ecs_sample.id
}

// --- パブリックサブネットのルーティング ---
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.ecs_sample.id
}

resource "aws_route" "public" {
  route_table_id         = aws_route_table.public.id
  gateway_id             = aws_internet_gateway.ecs_sample.id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route_table_association" "public_0" {
  subnet_id      = aws_subnet.public_0.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

// --- プライベートサブネット ---
resource "aws_subnet" "private_0" {
  vpc_id                  = aws_vpc.ecs_sample.id
  cidr_block              = "10.0.65.0/24" // cidr_blockは他のサブネットとかぶらないように
  availability_zone       = "ap-northeast-1a"
  map_public_ip_on_launch = false
}

resource "aws_subnet" "private_1" {
  vpc_id                  = aws_vpc.ecs_sample.id
  cidr_block              = "10.0.66.0/24"
  availability_zone       = "ap-northeast-1c"
  map_public_ip_on_launch = false
}

// --- プライベートサブネットのルーティング ---
resource "aws_route_table" "private_0" {
  vpc_id = aws_vpc.ecs_sample.id
}

resource "aws_route_table" "private_1" {
  vpc_id = aws_vpc.ecs_sample.id
}

resource "aws_route" "private_0" {
  route_table_id         = aws_route_table.private_0.id
  nat_gateway_id         = aws_nat_gateway.nat_gateway_0.id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route" "private_1" {
  route_table_id         = aws_route_table.private_1.id
  nat_gateway_id         = aws_nat_gateway.nat_gateway_1.id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route_table_association" "private_0" {
  subnet_id      = aws_subnet.private_0.id
  route_table_id = aws_route_table.private_0.id
}

resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private_1.id
}

// --- プライベートサブネットとNATの接続 ---
// Elastic IP
resource "aws_eip" "nat_gateway_0" {
  vpc        = true
  depends_on = [aws_internet_gateway.ecs_sample] // depends_onでIGWができるのを待つ
}

resource "aws_eip" "nat_gateway_1" {
  vpc        = true
  depends_on = [aws_internet_gateway.ecs_sample]
}

// NATゲートウェイ
resource "aws_nat_gateway" "nat_gateway_0" {
  allocation_id = aws_eip.nat_gateway_0.id
  subnet_id     = aws_subnet.public_0.id
  depends_on    = [aws_internet_gateway.ecs_sample]
}

resource "aws_nat_gateway" "nat_gateway_1" {
  allocation_id = aws_eip.nat_gateway_1.id
  subnet_id     = aws_subnet.public_1.id
  depends_on    = [aws_internet_gateway.ecs_sample]
}

// --- セキュリティグループ ---
resource "aws_security_group" "ecs_sample" {
  name   = "ecs-sample"
  vpc_id = aws_vpc.ecs_sample.id
}

// インバウンド
resource "aws_security_group_rule" "ingress_ecs_sample" {
  type              = "ingress"
  from_port         = "80"
  to_port           = "80"
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ecs_sample.id
}

// アウトバウンド
resource "aws_security_group_rule" "egress_ecs_sample" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ecs_sample.id
}
