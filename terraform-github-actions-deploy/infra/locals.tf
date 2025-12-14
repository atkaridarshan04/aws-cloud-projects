locals {
  project_name = "terraform-github-actions-deploy"

  # Backend configuration
  s3_bucket_name = "terraform-github-actions-deploy-state-bucket"
  dynamodb_table = "terraform-github-actions-deploy-locks"

  # Networking
  vpc_cidr    = "10.0.0.0/16"
  subnet_cidr = "10.0.1.0/24"
  az          = "eu-north-1a"

  # EC2
  instance_type = "t3.micro"
  ami_id        = "ami-0fa91bc90632c73c9" # Ubuntu
  key_name      = "ssh-keypair"

  # Security
  ingress_ports = [22, 8080]

  # ECR
  ecr_repo_name = "${local.project_name}-repo"
}
