#######################################
# 1️⃣ VPC
#######################################
resource "aws_vpc" "main" {
  cidr_block           = local.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name    = "${local.project_name}-vpc"
    Project = local.project_name
  }
}

#######################################
# 2️⃣ Public Subnet
#######################################
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.subnet_cidr
  availability_zone       = local.az
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.project_name}-public-subnet"
  }
}

#######################################
# 3️⃣ Internet Gateway
#######################################
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.project_name}-igw"
  }
}

#######################################
# 4️⃣ Route Table + Association
#######################################
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${local.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

#######################################
# 5️⃣ Security Group
#######################################
resource "aws_security_group" "ec2_sg" {
  name        = "${local.project_name}-sg"
  description = "Allow HTTP and SSH access"
  vpc_id      = aws_vpc.main.id

  # Allow inbound traffic on specified ports
  dynamic "ingress" {
    for_each = toset(local.ingress_ports)
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.project_name}-sg"
  }
}

#######################################
# 6️⃣ SSH Key Pair
#######################################
resource "tls_private_key" "deployer" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "deployer" {
  key_name   = local.key_name
  public_key = tls_private_key.deployer.public_key_openssh

  tags = {
    Name = "${local.project_name}-keypair"
  }
}

#######################################
# 7️⃣ EC2 Instance
#######################################
resource "aws_instance" "web" {
  ami                         = local.ami_id
  instance_type               = local.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.deployer.key_name
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name

  user_data = <<-EOF
              #!/bin/bash
              set -e
              # Update and install dependencies (Ubuntu)
              apt-get update -y
              apt-get install -y docker.io unzip curl
              systemctl enable docker
              systemctl start docker
              usermod -aG docker ubuntu

              # Install AWS CLI v2
              curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
              unzip /tmp/awscliv2.zip -d /tmp
              /tmp/aws/install

              # Allow docker without sudo for ubuntu user
              echo 'ubuntu ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
              EOF

  tags = {
    Name = "${local.project_name}-ec2"
  }
}

#######################################
# 8️⃣ ECR repository
#######################################
resource "aws_ecr_repository" "app" {
  name                 = local.ecr_repo_name
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  tags = {
    Name    = "${local.project_name}-ecr"
    Project = local.project_name
  }
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 5 images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 5
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Delete untagged images older than 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

#######################################
# 9️⃣ IAM role for EC2
#######################################

# IAM policy that allows ECR read and getting auth token (narrow set)
data "aws_iam_policy_document" "ec2_ecr_policy" {
  statement {
    sid = "AllowECRAuthAndPull"
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:DescribeImages"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role" "ec2_role" {
  name = "${local.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
  tags = {
    Project = local.project_name
  }
}

resource "aws_iam_role_policy" "ec2_ecr_policy_attach" {
  name   = "${local.project_name}-ec2-ecr-policy"
  role   = aws_iam_role.ec2_role.id
  policy = data.aws_iam_policy_document.ec2_ecr_policy.json
}

# Instance profile so EC2 can get the role
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${local.project_name}-instance-profile"
  role = aws_iam_role.ec2_role.name
}

# Attach AWS-managed policy for SSM
# resource "aws_iam_role_policy_attachment" "ec2_ssm" {
#   role       = aws_iam_role.ec2_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
# }