# Application Load Balancer - Internet-facing entry point
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false                        # Internet-facing for public access
  load_balancer_type = "application"                # Layer 7 load balancer
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id      # Public subnets for internet access

  enable_deletion_protection = false  # Allow deletion

  tags = {
    Name = "${var.project_name}-alb"
  }
}

# Target Group for ECS Fargate tasks
# Defines health check parameters and routing configuration
resource "aws_lb_target_group" "app" {
  name        = "${var.project_name}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"  # Required for Fargate tasks (not instance-based)

  # Health check configuration for container availability
  health_check {
    enabled             = true
    healthy_threshold   = 2      # Consecutive successful checks to mark healthy
    interval            = 30     # Health check frequency (seconds)
    matcher             = "200"  # Expected HTTP response code
    path                = "/"    # Health check endpoint
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5      # Health check timeout (seconds)
    unhealthy_threshold = 2      # Consecutive failed checks to mark unhealthy
  }

  tags = {
    Name = "${var.project_name}-tg"
  }
}

# ALB Listener - Routes incoming requests to target group
resource "aws_lb_listener" "app" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  # Default action forwards all traffic to ECS target group
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
