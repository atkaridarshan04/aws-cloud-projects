terraform {
  backend "s3" {
    # These values will be provided via terraform init -backend-config
    bucket         = "your-terraform-state-bucket"
    key            = "infra/terraform.tfstate"
    region         = "eu-north-1"
    dynamodb_table = "your-terraform-locks-table"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "eu-north-1"
}
