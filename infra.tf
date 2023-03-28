# Create a VPC
resource "aws_vpc" "demo_vpc" {
  cidr_block = "10.0.0.0/16"
}

# Create a private subnet
resource "aws_subnet" "demo_sub_pvt" {
  vpc_id     = aws_vpc.demo_vpc.id
  cidr_block = "10.0.1.0/24"
  tags = {
    Name = "private-subnet"
  }
}

# Create a public subnet
resource "aws_subnet" "demo_sub_pub" {
  vpc_id     = aws_vpc.demo_vpc.id
  cidr_block = "10.0.0.0/24"
  availability_zone = "ap-south-1a"
  tags = {
    Name = "public-subnet"
  }
}
resource "aws_subnet" "demo_sub_pub2" {
  vpc_id            = aws_vpc.demo_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-south-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet2"
  }
}


# Create a security group
resource "aws_security_group" "demo_sg" {
  name_prefix = "demo-sg"
  vpc_id      = aws_vpc.demo_vpc.id

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_internet_gateway" "demo_igw" {
  vpc_id = aws_vpc.demo_vpc.id

  tags = {
    Name = "demo-igw"
  }
}

resource "aws_route_table" "demo_public_rt" {
  vpc_id = aws_vpc.demo_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.demo_igw.id
  }

  tags = {
    Name = "demo-public-rt"
  }
}

resource "aws_route_table_association" "demo_public_subnet_a_rt" {
  subnet_id      = aws_subnet.demo_sub_pub.id
  route_table_id = aws_route_table.demo_public_rt.id
}

resource "aws_route_table_association" "demo_public_subnet_b_rt" {
  subnet_id      = aws_subnet.demo_sub_pub2.id
  route_table_id = aws_route_table.demo_public_rt.id
}


# Create an Elastic Load Balancer (ELB)
resource "aws_lb" "demo_lb" {
  name               = "demo-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.demo_sg.id]
  subnets            = [aws_subnet.demo_sub_pub.id, aws_subnet.demo_sub_pub2.id]

  tags = {
    Name = "demo-lb"
  }
}

# Create a target group for the ECS service to use
resource "aws_lb_target_group" "demo_target_group" {
  name        = "demo-target-group"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.demo_vpc.id
  target_type = "ip"

  health_check {
    path     = "/"
    protocol = "HTTP"
    matcher  = "200-299"
    interval = 30
    timeout  = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
  # Attach load balancer to target group
  load_balancers     = [aws_lb.demo_lb.arn]
}


resource "aws_iam_policy" "ecs_policy" {
  name        = "ecs_policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "ecs:CreateCluster",
          "ecs:DeregisterContainerInstance",
          "ecs:DiscoverPollEndpoint",
          "ecs:Poll",
          "ecs:RegisterContainerInstance",
          "ecs:StartTelemetrySession",
          "ecs:Submit*",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role" "ecs_role" {
  name               = "ecs_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "ecs_role"
  }

}
resource "aws_iam_role_policy_attachment" "ecs_policy_attachment" {
  policy_arn = aws_iam_policy.ecs_policy.arn
  role       = aws_iam_role.ecs_role.name
}
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs_task_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}


resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  role       = aws_iam_role.ecs_task_execution_role.name
}

# Create an ECS cluster
resource "aws_ecs_cluster" "demo_cluster" {
  name = "demo-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# Create an ECS task definition for the application
resource "aws_ecs_task_definition" "demo_task_definition" {
  family                   = "demo-task-definition"
  container_definitions    = jsonencode([{
    name                    = "demo-app"
    image                   = "634441478571.dkr.ecr.ap-south-1.amazonaws.com/demo-app:latest"

    essential               = true
    portMappings = [
      {
        containerPort       = 3000
        hostPort            = 3000
        protocol            = "tcp"
      }
    ]
  }])
  cpu                      = 256
  memory                   = 512
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  task_role_arn            = aws_iam_role.ecs_role.arn
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
}



# Create an ECS service for the application
resource "aws_ecs_service" "demo_service" {
  name            = "demo-service"
  cluster         = aws_ecs_cluster.demo_cluster.id
  task_definition = aws_ecs_task_definition.demo_task_definition.arn
  desired_count   = 1

  deployment_controller {
    type = "ECS"
  }

  network_configuration {
    security_groups = [aws_security_group.demo_sg.id]
    subnets         = [aws_subnet.demo_sub_pvt.id, aws_subnet.demo_sub_pub.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.demo_target_group.arn
    container_name   = "demo-app"
    container_port   = 3000
  }
}
