#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting EKS Fargate cluster setup...${NC}"

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}AWS CLI is not installed. Please install it first.${NC}"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}AWS credentials are not configured or invalid. Please configure them first.${NC}"
    exit 1
fi

# Check Terraform
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}Terraform is not installed. Please install it first.${NC}"
    exit 1
fi

# Check if S3 bucket exists, if not create it
S3_BUCKET="eks-fargate-terraform-state-bucket"
if ! aws s3 ls "s3://${S3_BUCKET}" &> /dev/null; then
    echo -e "${YELLOW}Creating S3 bucket for Terraform state: ${S3_BUCKET}${NC}"
    aws s3 mb "s3://${S3_BUCKET}"
    aws s3api put-bucket-versioning --bucket "${S3_BUCKET}" --versioning-configuration Status=Enabled
    aws s3api put-bucket-encryption --bucket "${S3_BUCKET}" --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
else
    echo -e "${GREEN}S3 bucket for Terraform state already exists.${NC}"
fi

# Check if DynamoDB table exists, if not create it
if ! aws dynamodb describe-table --table-name terraform-state-lock &> /dev/null; then
    echo -e "${YELLOW}Creating DynamoDB table for Terraform state locking...${NC}"
    aws dynamodb create-table \
        --table-name terraform-state-lock \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5
else
    echo -e "${GREEN}DynamoDB table for Terraform state locking already exists.${NC}"
fi

# Initialize Terraform
echo -e "${YELLOW}Initializing Terraform...${NC}"
terraform init

# Plan Terraform configuration
echo -e "${YELLOW}Planning Terraform configuration...${NC}"
terraform plan -out=tfplan

# Apply Terraform configuration
echo -e "${YELLOW}Applying Terraform configuration...${NC}"
terraform apply tfplan

# Configure kubectl
echo -e "${YELLOW}Configuring kubectl...${NC}"
CLUSTER_NAME=$(terraform output -raw eks_cluster_name)
REGION=$(terraform output -raw aws_region 2>/dev/null || echo "us-east-1")
aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${REGION}

# Deploy AWS Load Balancer Controller
echo -e "${YELLOW}Deploying AWS Load Balancer Controller...${NC}"
./deploy-alb-controller.sh

# Deploy sample application
echo -e "${YELLOW}Deploying sample application...${NC}"
./deploy-app.sh

echo -e "${GREEN}EKS Fargate cluster setup completed successfully!${NC}"
echo -e "${YELLOW}You can now interact with your cluster using kubectl.${NC}"

# Output important information
echo -e "${YELLOW}-----------------------------------------${NC}"
echo -e "${YELLOW}Cluster Information:${NC}"
echo -e "${YELLOW}-----------------------------------------${NC}"
echo -e "${GREEN}Cluster Name:${NC} ${CLUSTER_NAME}"
echo -e "${GREEN}Region:${NC} ${REGION}"
echo -e "${GREEN}VPC ID:${NC} $(terraform output -raw vpc_id)"
echo -e "${GREEN}Fargate Profile:${NC} $(terraform output -raw test_app_fargate_profile_arn)"

echo -e "${YELLOW}-----------------------------------------${NC}"
echo -e "${YELLOW}To access your application:${NC}"
echo -e "${YELLOW}-----------------------------------------${NC}"
echo -e "kubectl get ingress -n test-app -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'"
echo -e "${YELLOW}(Note: It may take a few minutes for the ALB to be provisioned)${NC}"

echo -e "${YELLOW}-----------------------------------------${NC}"
echo -e "${YELLOW}To clean up all resources:${NC}"
echo -e "${YELLOW}-----------------------------------------${NC}"
echo -e "terraform destroy"