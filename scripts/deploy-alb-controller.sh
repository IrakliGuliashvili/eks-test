#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

CLUSTER_NAME=$(terraform output -raw eks_cluster_name)
REGION=$(terraform output -raw aws_region 2>/dev/null || echo "us-east-1")
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)

echo -e "${YELLOW}Deploying AWS Load Balancer Controller to EKS cluster: ${CLUSTER_NAME}${NC}"

# Create IAM policy for ALB controller
echo -e "${YELLOW}Creating IAM policy for ALB controller...${NC}"
POLICY_ARN=$(aws iam list-policies --query "Policies[?PolicyName=='AWSLoadBalancerControllerIAMPolicy'].Arn" --output text)

if [ -z "$POLICY_ARN" ]; then
  echo -e "${YELLOW}Downloading ALB controller policy document...${NC}"
  curl -o alb-controller-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
  
  echo -e "${YELLOW}Creating IAM policy...${NC}"
  POLICY_ARN=$(aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://alb-controller-policy.json \
    --query "Policy.Arn" \
    --output text)
  
  rm alb-controller-policy.json
else
  echo -e "${GREEN}IAM policy for ALB controller already exists.${NC}"
fi

echo -e "${GREEN}IAM policy ARN: ${POLICY_ARN}${NC}"

# Create service account for ALB controller
echo -e "${YELLOW}Creating Kubernetes service account for ALB controller...${NC}"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: aws-load-balancer-controller
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::${ACCOUNT_ID}:role/AmazonEKSLoadBalancerControllerRole
EOF

# Create IAM role for ALB controller
echo -e "${YELLOW}Creating IAM role for ALB controller...${NC}"
OIDC_PROVIDER=$(aws eks describe-cluster --name ${CLUSTER_NAME} --query "cluster.identity.oidc.issuer" --output text | sed -e "s/^https:\/\///")

# Check if role already exists
ROLE_EXISTS=$(aws iam get-role --role-name AmazonEKSLoadBalancerControllerRole 2>/dev/null || echo "false")

if [ "$ROLE_EXISTS" == "false" ]; then
  # Create trust relationship policy document
  cat <<EOF > trust-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/${OIDC_PROVIDER}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${OIDC_PROVIDER}:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }
  ]
}
EOF

  # Create IAM role
  aws iam create-role \
    --role-name AmazonEKSLoadBalancerControllerRole \
    --assume-role-policy-document file://trust-policy.json

  # Attach policy to role
  aws iam attach-role-policy \
    --role-name AmazonEKSLoadBalancerControllerRole \
    --policy-arn ${POLICY_ARN}
  
  rm trust-policy.json
else
  echo -e "${GREEN}IAM role for ALB controller already exists.${NC}"
fi

# Install AWS Load Balancer Controller using Helm
echo -e "${YELLOW}Installing AWS Load Balancer Controller using Helm...${NC}"

# Add the EKS chart repository
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Install the AWS Load Balancer Controller
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --namespace kube-system \
  --set clusterName=${CLUSTER_NAME} \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=${REGION} \
  --set vpcId=$(terraform output -raw vpc_id)

# Verify installation
echo -e "${YELLOW}Verifying AWS Load Balancer Controller installation...${NC}"
kubectl get deployment -n kube-system aws-load-balancer-controller

echo -e "${GREEN}AWS Load Balancer Controller deployed successfully!${NC}"