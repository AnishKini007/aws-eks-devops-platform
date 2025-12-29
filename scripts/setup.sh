#!/bin/bash
# Setup script for EKS platform

set -e

echo "=========================================="
echo "  AWS EKS Platform Setup Script"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}Checking prerequisites...${NC}"
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        echo -e "${RED}AWS CLI is not installed. Please install it first.${NC}"
        exit 1
    fi
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        echo -e "${RED}Terraform is not installed. Please install it first.${NC}"
        exit 1
    fi
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}kubectl is not installed. Please install it first.${NC}"
        exit 1
    fi
    
    # Check Helm
    if ! command -v helm &> /dev/null; then
        echo -e "${RED}Helm is not installed. Please install it first.${NC}"
        exit 1
    fi
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Docker is not installed. Please install it first.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}All prerequisites are installed!${NC}"
}

# Deploy infrastructure
deploy_infrastructure() {
    echo -e "${YELLOW}Deploying infrastructure with Terraform...${NC}"
    
    cd terraform/environments/dev
    
    terraform init
    terraform plan -out=tfplan
    
    read -p "Do you want to apply this plan? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        terraform apply tfplan
    else
        echo "Deployment cancelled."
        exit 0
    fi
    
    cd ../../..
    echo -e "${GREEN}Infrastructure deployed successfully!${NC}"
}

# Configure kubectl
configure_kubectl() {
    echo -e "${YELLOW}Configuring kubectl...${NC}"
    
    CLUSTER_NAME=$(cd terraform/environments/dev && terraform output -raw eks_cluster_name)
    REGION=$(cd terraform/environments/dev && terraform output -raw aws_region 2>/dev/null || echo "us-east-1")
    
    aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION
    
    echo -e "${GREEN}kubectl configured successfully!${NC}"
}

# Deploy ArgoCD
deploy_argocd() {
    echo -e "${YELLOW}Deploying ArgoCD...${NC}"
    
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    
    echo "Waiting for ArgoCD to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
    
    # Get initial admin password
    echo -e "${GREEN}ArgoCD deployed successfully!${NC}"
    echo "ArgoCD admin password:"
    kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
    echo ""
}

# Deploy platform applications
deploy_applications() {
    echo -e "${YELLOW}Deploying platform applications via ArgoCD...${NC}"
    
    kubectl apply -f argocd/projects/
    kubectl apply -f argocd/apps/
    
    echo -e "${GREEN}Applications deployed successfully!${NC}"
}

# Main menu
main() {
    check_prerequisites
    
    echo ""
    echo "Select an option:"
    echo "1) Deploy everything (infrastructure + applications)"
    echo "2) Deploy infrastructure only"
    echo "3) Configure kubectl only"
    echo "4) Deploy ArgoCD only"
    echo "5) Deploy applications only"
    echo "6) Exit"
    
    read -p "Enter your choice (1-6): " choice
    
    case $choice in
        1)
            deploy_infrastructure
            configure_kubectl
            deploy_argocd
            deploy_applications
            ;;
        2)
            deploy_infrastructure
            ;;
        3)
            configure_kubectl
            ;;
        4)
            deploy_argocd
            ;;
        5)
            deploy_applications
            ;;
        6)
            exit 0
            ;;
        *)
            echo "Invalid option"
            exit 1
            ;;
    esac
    
    echo ""
    echo -e "${GREEN}=========================================="
    echo "  Setup Complete!"
    echo "==========================================${NC}"
}

main "$@"
