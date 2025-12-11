# 🚀 Deploying Using Terraform

## 📋 Deployment Steps

### 1. **Navigate to the Terraform Directory**

```bash
cd terraform
```

### 2. **Set Required Variables**

Create a `terraform.tfvars` file with your specific values:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit the `terraform.tfvars` file and provide:

```hcl
# Required Variables
github_repo = "https://github.com/your-username/your-repo"
github_token = "your-github-personal-access-token"

# Optional Variables (defaults provided)
aws_region = "us-east-1"
project_name = "ecs-cicd-pipeline"
ecr_repository_name = "container-orchestration-repo"
github_branch = "main"
container_port = 5173
alb_port = 80
desired_count = 2
cpu = 256
memory = 512
```

> **Note:** Generate a GitHub Personal Access Token with `repo` permissions for CodePipeline integration.

### 3. **Initialize Terraform**

This command initializes the Terraform environment, downloads required providers, and sets up the backend.

```bash
terraform init
```

### 4. **Plan Infrastructure**

Run the plan command to see what Terraform will create, modify, or destroy:

```bash
terraform plan
```

This helps verify that the setup will match your expectations before actually applying the changes.

### 5. **Apply and Deploy**

Deploy the infrastructure with the following command. This will create all the resources defined in your Terraform configuration:

```bash
terraform apply --auto-approve
```

<!-- ![tf-output](../assets/tf-output.png) -->

### 6. **Initial Image Push (First Time Only)**

For the first deployment, you need to push an initial image to ECR:

```bash
# Get ECR login token
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com

# Build and tag your image
docker build -t container-orchestration-repo .
docker tag container-orchestration-repo:latest <account-id>.dkr.ecr.us-east-1.amazonaws.com/container-orchestration-repo:latest

# Push to ECR
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/container-orchestration-repo:latest
```

### 7. **Accessing Your Application**

After deployment, wait for the ECS service to become healthy. Check the output for the **ALB DNS name**. Open this in your web browser to verify that the setup is working.

<!-- ![app-home](../assets/web-v1.png) -->

### 8. **Verify CI/CD Pipeline**

1. **Push code changes** to your GitHub repository
2. **Monitor CodePipeline** in AWS Console - it should automatically trigger
3. **Check ECR** for new image versions
4. **Verify ECS service** updates with new task definition
5. **Test application** via ALB DNS to see changes

<!-- ![pipeline-success](../assets/cp-6.png) -->

## 📝 Outputs

Once the infrastructure is deployed, Terraform will output:

- **ALB DNS Name**: Access your application through the load balancer
- **ECR Repository URL**: Docker image repository
- **ECS Cluster Name**: Container cluster identifier
- **CodePipeline Name**: CI/CD pipeline identifier

## 🧹 Clean Up Resources

To destroy all provisioned AWS resources:

```bash
terraform destroy --auto-approve
```

---