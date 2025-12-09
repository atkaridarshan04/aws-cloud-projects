# Security Group for the Application Load Balancer
resource "aws_security_group" "lb_sg" {
  name        = "${var.name}-lb-sg"
  description = "Security group for ALB"
  vpc_id      = module.vpc.vpc_id

  # Allow inbound HTTP traffic from anywhere on the internet
  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # When HTTPS (TLS) is configured
  #   ingress {
  #     description = "Allow HTTPS"
  #     from_port   = 443
  #     to_port     = 443
  #     protocol    = "tcp"
  #     cidr_blocks = ["0.0.0.0/0"]
  #   }

  # Allow all outbound traffic
  # Required for ALB to communicate with EC2 targets
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.name}-lb-sg"
    Environment = var.env
  }
}

# Target Group that contains the EC2 instances
resource "aws_lb_target_group" "lb_tg" {
  name     = "${var.name}-lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  # Health check configuration
  health_check {
    path                = "/"       # Endpoint to check
    interval            = 30        # Check every 30 seconds
    timeout             = 5         # Fail if no response in 5 seconds
    healthy_threshold   = 2         # 2 successes = healthy
    unhealthy_threshold = 2         # 2 failures = unhealthy   
    protocol            = "HTTP"   
  }

  tags = {
    Environment = var.env
  }
}

# Application Load Balancer
resource "aws_lb" "alb" {
  name               = "${var.name}-alb"
  internal           = false # public facing ALB
  load_balancer_type = "application"

  # Attach ALB security group
  security_groups    = [aws_security_group.lb_sg.id]

  # ALB placed in multiple public subnets (multi-AZ)
  subnets            = module.vpc.public_subnets

  # Optional safety mechanism to prevent accidental deletion
  # enable_deletion_protection = true

  # Optional access logging
  #   access_logs {
  #     bucket  = aws_s3_bucket.lb_logs.id
  #     prefix  = "alb-logs"
  #     enabled = true
  #   }

  tags = {
    Name        = "${var.name}-alb"
    Environment = var.env
  }
}

# ALB Listner
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  # Forward all incoming traffic to the target group
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb_tg.arn
  }

  tags = {
    Environment = var.env
  }
}
