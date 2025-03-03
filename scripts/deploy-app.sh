#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

NAMESPACE="test-app"

echo -e "${YELLOW}Deploying sample application to namespace: ${NAMESPACE}${NC}"

# Check if the namespace exists
if ! kubectl get namespace ${NAMESPACE} > /dev/null 2>&1; then
  echo -e "${YELLOW}Creating namespace ${NAMESPACE}...${NC}"
  kubectl apply -f ../k8s/test-app/namespace.yaml
fi

# Deploy the application
echo -e "${YELLOW}Deploying application resources...${NC}"
kubectl apply -f ../k8s/test-app/deployment.yaml
kubectl apply -f ../k8s/test-app/service.yaml
kubectl apply -f ../k8s/test-app/ingress.yaml

# Wait for pods to be ready
echo -e "${YELLOW}Waiting for pods to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app=nginx-app -n ${NAMESPACE} --timeout=300s

# Get pod status
echo -e "${YELLOW}Pod status:${NC}"
kubectl get pods -n ${NAMESPACE}

# Get service details
echo -e "${YELLOW}Service details:${NC}"
kubectl get svc -n ${NAMESPACE}

# Get ingress details (may take some time to provision the ALB)
echo -e "${YELLOW}Ingress details (ALB may take a few minutes to provision):${NC}"
kubectl get ingress -n ${NAMESPACE}

echo -e "${GREEN}Application deployment complete!${NC}"
echo -e "${YELLOW}You can access the application through the ALB URL once it's provisioned.${NC}"
echo -e "${YELLOW}To get the ALB URL, run:${NC}"
echo -e "kubectl get ingress -n ${NAMESPACE} -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'"