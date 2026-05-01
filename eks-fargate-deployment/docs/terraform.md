# 🚀 Deploying EKS Fargate + ALB with Terraform

This guide provisions the AWS infrastructure with Terraform, then deploys the ALB controller and the 2048 app with `helm` and `kubectl`.

**What Terraform provisions:** VPC, subnets, IGW, NAT gateway, EKS cluster, two Fargate profiles, OIDC provider, and all IAM roles.

**What you run after apply:** `helm install` for the ALB controller and `kubectl apply` for the app — these require a live cluster and are a one-time post-apply step.

---

## ✅ Prerequisites

- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) configured (`aws configure`)
- [Terraform](https://developer.hashicorp.com/terraform/install) installed
- [kubectl](https://kubernetes.io/docs/tasks/tools/) installed
- [Helm](https://helm.sh/docs/intro/install/) installed

---

## 📁 File Structure

```
terraform/
├── providers.tf                    # AWS provider ~6.0
├── variables.tf                    # aws_region, cluster_name
├── main.tf                         # wires vpc, eks, iam modules together
├── outputs.tf                      # surfaces module outputs
├── terraform.tfvars.example
├── alb_controller_iam_policy.json  # Official AWS LBC IAM policy (v2.11.0)
└── modules/
    ├── vpc/                        # VPC, public/private subnets, IGW, NAT gateway
    ├── eks/                        # EKS cluster, Fargate profiles, OIDC provider
    └── iam/                        # Cluster role, Fargate execution role, ALB controller IRSA role
```

---

## 🚀 Part 1 — Terraform (AWS Infrastructure)

### 1. Set variables

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
aws_region   = "us-east-1"
cluster_name = "demo-cluster"
```

### 2. Init + apply

```bash
terraform init
terraform apply
```

Type `yes`. Takes **10–15 minutes** — EKS cluster creation and Fargate profile provisioning are slow.

Outputs:
```
alb_controller_role_arn = "arn:aws:iam::<account>:role/AmazonEKSLoadBalancerControllerRole"
aws_region              = "us-east-1"
cluster_name            = "demo-cluster"
cluster_endpoint        = "https://..."
vpc_id                  = "vpc-..."
```

---

## 🚀 Part 2 — Post-Apply Steps (kubectl + helm)

### 3. Update kubeconfig

```bash
aws eks update-kubeconfig \
  --name $(terraform output -raw cluster_name) \
  --region $(terraform output -raw aws_region)
```

### 4. Patch CoreDNS for Fargate

CoreDNS is deployed as a Deployment by default with an annotation that prevents it from running on Fargate. Patch it:

```bash
kubectl patch deployment coredns \
  -n kube-system \
  --type json \
  -p='[{"op":"remove","path":"/spec/template/metadata/annotations/eks.amazonaws.com~1compute-type"}]'
```

### 5. Create the ALB controller service account

```bash
kubectl create serviceaccount aws-load-balancer-controller -n kube-system

kubectl annotate serviceaccount aws-load-balancer-controller \
  -n kube-system \
  eks.amazonaws.com/role-arn=$(terraform output -raw alb_controller_role_arn)
```

### 6. Install the ALB Ingress Controller via Helm

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$(terraform output -raw cluster_name) \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=$(terraform output -raw aws_region) \
  --set vpcId=$(terraform output -raw vpc_id)
```

Verify it's running:
```bash
kubectl get deployment -n kube-system aws-load-balancer-controller
```

### 7. Deploy the 2048 app

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.5.4/docs/examples/2048/2048_full.yaml
```

### 8. Get the ALB address

```bash
kubectl get ingress -n game-2048
```

Wait ~3 minutes for the ALB to provision. Copy the `ADDRESS` and open it in a browser.

---

## 🔥 Cleanup

```bash
# Delete the app and ALB (must be done before terraform destroy — otherwise the ALB
# created by the controller won't be in Terraform state and will block VPC deletion)
kubectl delete -f https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.5.4/docs/examples/2048/2048_full.yaml
helm uninstall aws-load-balancer-controller -n kube-system

# Wait for the ALB to be fully deleted, then destroy infrastructure
terraform destroy --auto-approve
```

> **Important:** Always delete the Kubernetes Ingress (and wait for the ALB to be removed) before running `terraform destroy`. The ALB is created by the controller outside of Terraform state — if it still exists when Terraform tries to delete the VPC, the destroy will fail because the VPC has a dependency on the ALB's ENIs.
