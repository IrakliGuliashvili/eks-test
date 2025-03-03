# AWS EKS Fargate Terraform Project

This repository contains Terraform configuration to deploy a production-ready Amazon EKS cluster with Fargate profiles.

## Architecture Overview

![EKS Fargate Architecture](https://raw.githubusercontent.com/yourusername/eks-fargate-terraform/main/docs/architecture.png)

The architecture includes:

- **VPC** with private and public subnets across two availability zones
- **EKS Cluster** with private networking for the Kubernetes control plane
- **Fargate Profiles** for serverless compute resources
- **AWS Load Balancer Controller** for ingress management
- **CloudWatch** integration for logging and monitoring
- **Sample application** deployed to demonstrate functionality

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.0.0
- kubectl >= 1.21
- Access to AWS with permissions to create all required resources

## Project Structure

```
eks-fargate-terraform/
├── main.tf                  # Main Terraform configuration
├── variables.tf             # Root variables
├── outputs.tf               # Root outputs
├── providers.tf             # Provider configuration
├── backend.tf               # S3 backend configuration
├── modules/
│   ├── vpc/                 # VPC module
│   ├── eks/                 # EKS cluster module
│   ├── fargate-profiles/    # Fargate profiles module
│   ├── logging/             # Logging module
│   └── monitoring/          # Monitoring module
├── k8s/                     # Kubernetes manifests
│   └── test-app/            # Sample application
├── scripts/
│   ├── setup.sh             # Main setup script
│   └── deploy-app.sh        # Application deployment script
└── docs/                    # Documentation
    └── architecture.png     # Architecture diagram
```

## Deployment Instructions

### 1. Initialize the S3 Backend (First Time Only)

Before the first deployment, you need to create an S3 bucket and DynamoDB table for Terraform state:

```bash
aws s3 mb s3://test-app-eks-fargate-terraform-state-bucket
aws dynamodb create-table \
    --table-name test-app-terraform-state-lock \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5


### 2. Terraform Deployment

```bash
# Initialize Terraform
terraform init

# Plan the deployment
terraform plan -out=tfplan

# Apply the configuration
terraform apply tfplan
```

### 3. Configure kubectl

After the EKS cluster is created, configure kubectl to interact with it:

```bash
aws eks update-kubeconfig --name eks-fargate-cluster --region us-east-1
```

### 4. Deploy AWS Load Balancer Controller

The AWS Load Balancer Controller is required for Ingress resources:

```bash
./scripts/deploy-alb-controller.sh
```

### 5. Deploy Sample Application

```bash
kubectl apply -f k8s/test-app/namespace.yaml
kubectl apply -f k8s/test-app/deployment.yaml
kubectl apply -f k8s/test-app/service.yaml
kubectl apply -f k8s/test-app/ingress.yaml
```

Or use the provided script:

```bash
./scripts/deploy-app.sh
```

### 6. Verify Deployment

```bash
# Check Fargate profiles
aws eks list-fargate-profiles --cluster-name eks-fargate-cluster --region us-east-1

# Check pods
kubectl get pods -n test-app

# Check service
kubectl get svc -n test-app

# Check ingress
kubectl get ingress -n test-app
```

The sample application should be accessible via the ALB DNS name shown in the ingress details.

## Security Considerations

This deployment implements several security best practices:

1. **Private Networking**: EKS control plane is deployed with private endpoint access
2. **IAM Roles for Service Accounts (IRSA)**: Used for fine-grained permissions
3. **Security Groups**: Properly configured to restrict traffic
4. **RBAC**: Kubernetes RBAC enabled for access control
5. **Secrets Management**: AWS Secrets Manager integration for sensitive data

## Monitoring and Logging

- **Control Plane Logging**: Enabled to CloudWatch
- **Container Insights**: Configured for metrics collection
- **Fargate Pod Logs**: Directed to CloudWatch Log Groups

## Cost Optimization

- **Fargate Profiles**: Pay only for the resources used by your pods
- **Spot Instances**: Optional configuration for non-critical workloads
- **Right-sizing**: Resource requests and limits properly configured

## Cleanup

To avoid incurring unnecessary costs, clean up the resources when no longer needed:

```bash
terraform destroy
```

## Troubleshooting

Common issues and their solutions:

1. **Fargate Profile Creation Timeout**: Increase timeout in Terraform configuration
2. **Load Balancer Controller Issues**: Check IAM permissions and OIDC provider configuration
3. **Networking Problems**: Verify VPC, subnet, and security group configurations

For more detailed troubleshooting, check CloudWatch Logs or EKS console.

## Architecture Decisions

### VPC Design
- Two availability zones for high availability
- Private subnets for EKS nodes and Fargate pods
- Public subnets for load balancers and NAT gateways

### EKS Configuration
- Private networking for control plane security
- Fargate-only for simplified management
- Latest stable Kubernetes version for up-to-date features

### Networking
- AWS Load Balancer Controller for ALB/NLB integration
- Security groups configured for least privilege
- NAT gateways in each AZ for redundancy

## Contributing

1. Fork the repository
2. Create a feature branch
3. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.# eks-fargate-terraform
