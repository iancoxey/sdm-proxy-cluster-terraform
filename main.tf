data "aws_availability_zones" "available" {}

# VPC
resource "aws_vpc" "sdm_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  tags                 = { Name = "sdm-proxy-vpc" }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.sdm_vpc.id
  tags   = { Name = "sdm-igw" }
}

# Public Subnets
resource "aws_subnet" "public" {
  for_each = zipmap(data.aws_availability_zones.available.names, var.public_subnet_cidrs)
  vpc_id            = aws_vpc.sdm_vpc.id
  cidr_block        = each.value
  availability_zone = each.key
  map_public_ip_on_launch = true
  tags              = { Name = "sdm-public-${each.key}" }
}

# Private Subnets
resource "aws_subnet" "private" {
  for_each = zipmap(data.aws_availability_zones.available.names, var.private_subnet_cidrs)
  vpc_id            = aws_vpc.sdm_vpc.id
  cidr_block        = each.value
  availability_zone = each.key
  map_public_ip_on_launch = false
  tags              = { Name = "sdm-private-${each.key}" }
}

# Public Route Table and Associations
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.sdm_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "sdm-public-rt" }
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# NAT Gateways and Private Route Tables
resource "aws_eip" "nat" {
  for_each = aws_subnet.public
  #vpc      = true
}

resource "aws_nat_gateway" "nat" {
  for_each      = aws_subnet.public
  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = each.value.id
  tags          = { Name = "sdm-nat-${each.key}" }
}

resource "aws_route_table" "private" {
  for_each = aws_subnet.private
  vpc_id = aws_vpc.sdm_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[each.key].id
  }
  tags = { Name = "sdm-private-rt-${each.key}" }
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

# Security Group for Proxy Tasks
resource "aws_security_group" "sdm_tasks_sg" {
  name        = "sdm-proxy-tasks-sg"
  description = "Allow inbound from NLB to proxy tasks"
  vpc_id      = aws_vpc.sdm_vpc.id

  ingress {
    description = "Allow NLB to reach proxy tasks"
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Network Load Balancer (public)
resource "aws_lb" "sdm_nlb" {
  name               = "sdm-proxy-nlb"
  load_balancer_type = "network"
  internal           = false
  subnets            = [for s in aws_subnet.public : s.id]
  tags               = { Name = "sdm-proxy-nlb" }
}

# Target Group
resource "aws_lb_target_group" "sdm_tg" {
  name        = "sdm-proxy-tg"
  port        = 8443
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = aws_vpc.sdm_vpc.id

  health_check {
    protocol            = "TCP"
    port                = "8443"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 10
    interval            = 30
  }
  tags = { Name = "sdm-proxy-tg" }
}

# NLB Listener
resource "aws_lb_listener" "sdm_listener" {
  load_balancer_arn = aws_lb.sdm_nlb.arn
  port              = 443
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.sdm_tg.arn
  }
}

# ECS Service attaching to NLB target group
resource "aws_ecs_service" "sdm_service" {
  name            = "sdm-proxy-service"
  cluster         = aws_ecs_cluster.sdm_cluster.id
  task_definition = aws_ecs_task_definition.sdm_proxy.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [for s in aws_subnet.private : s.id]
    security_groups  = [aws_security_group.sdm_tasks_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.sdm_tg.arn
    container_name   = "sdm-proxy"
    container_port   = 8443
  }

  depends_on = [aws_lb_listener.sdm_listener]
}
# IAM Role & Policy for ECS Tasks
resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "ecsTaskExecutionRole-sdm-proxy"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
}

data "aws_iam_policy_document" "ecs_task_assume_role" {
  statement {
    effect    = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "sdm_logs" {
  name              = "/sdm/proxy"
  retention_in_days = 14
}

# ECS Cluster
resource "aws_ecs_cluster" "sdm_cluster" {
  name = var.sdm_cluster_name
}

# ECS Task Definition
resource "aws_ecs_task_definition" "sdm_proxy" {
  family                   = "sdm-proxy"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = tostring(var.container_cpu)
  memory                   = tostring(var.container_memory)
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "sdm-proxy"
      image     = var.sdm_proxy_image
      essential = true
      portMappings = [
        { containerPort = 8443, hostPort = 8443, protocol = "tcp" }
      ]

        environment = [
  { name  = "SDM_PROXY_CLUSTER_ACCESS_KEY", value = sdm_proxy_cluster_key.proxy_key.id },
  { name  = "SDM_PROXY_CLUSTER_SECRET_KEY", value = sdm_proxy_cluster_key.proxy_key.secret_key },
]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.sdm_logs.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "proxy"
        }
      }
    }
  ])
}
