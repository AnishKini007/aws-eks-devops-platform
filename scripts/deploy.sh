#!/bin/bash
# deploy.sh - Helm-based deployment script for AWS EKS Platform
# This script deploys all platform components using Helm charts

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE_MICROSERVICES="microservices"
NAMESPACE_MONITORING="monitoring"
NAMESPACE_JENKINS="jenkins"
NAMESPACE_ARGOCD="argocd"

AWS_REGION="${AWS_REGION:-us-east-1}"
CLUSTER_NAME="${CLUSTER_NAME:-eks-platform-dev}"

# Print functions
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Check prerequisites
check_prerequisites() {
    info "Checking prerequisites..."
    
    command -v helm >/dev/null 2>&1 || error "helm is required but not installed"
    command -v kubectl >/dev/null 2>&1 || error "kubectl is required but not installed"
    command -v aws >/dev/null 2>&1 || error "aws-cli is required but not installed"
    
    # Check Helm version
    HELM_VERSION=$(helm version --short | cut -d'+' -f1 | cut -d'v' -f2)
    if [[ "${HELM_VERSION}" < "3.10" ]]; then
        error "Helm 3.10+ is required. Found: ${HELM_VERSION}"
    fi
    
    success "All prerequisites met"
}

# Configure kubectl context
configure_kubectl() {
    info "Configuring kubectl for cluster: ${CLUSTER_NAME}..."
    
    aws eks update-kubeconfig \
        --name "${CLUSTER_NAME}" \
        --region "${AWS_REGION}"
    
    # Verify connection
    kubectl cluster-info || error "Failed to connect to cluster"
    
    success "kubectl configured successfully"
}

# Add Helm repositories
add_helm_repos() {
    info "Adding Helm repositories..."
    
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo add jenkins https://charts.jenkins.io
    helm repo add eks https://aws.github.io/eks-charts
    helm repo add autoscaler https://kubernetes.github.io/autoscaler
    helm repo add argo https://argoproj.github.io/argo-helm
    
    helm repo update
    
    success "Helm repositories added"
}

# Create namespaces
create_namespaces() {
    info "Creating namespaces..."
    
    kubectl create namespace ${NAMESPACE_MICROSERVICES} --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace ${NAMESPACE_MONITORING} --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace ${NAMESPACE_JENKINS} --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace ${NAMESPACE_ARGOCD} --dry-run=client -o yaml | kubectl apply -f -
    
    success "Namespaces created"
}

# Deploy AWS Load Balancer Controller
deploy_alb_controller() {
    info "Deploying AWS Load Balancer Controller..."
    
    helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
        --namespace kube-system \
        -f helm/values/aws-load-balancer-controller.yaml \
        --wait \
        --timeout 5m
    
    success "AWS Load Balancer Controller deployed"
}

# Deploy Cluster Autoscaler
deploy_cluster_autoscaler() {
    info "Deploying Cluster Autoscaler..."
    
    helm upgrade --install cluster-autoscaler autoscaler/cluster-autoscaler \
        --namespace kube-system \
        -f helm/values/cluster-autoscaler.yaml \
        --wait \
        --timeout 5m
    
    success "Cluster Autoscaler deployed"
}

# Deploy Monitoring Stack (Prometheus + Grafana)
deploy_monitoring() {
    info "Deploying Monitoring Stack (Prometheus + Grafana)..."
    
    helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
        --namespace ${NAMESPACE_MONITORING} \
        -f helm/values/monitoring.yaml \
        --wait \
        --timeout 10m
    
    # Print Grafana access info
    GRAFANA_PASSWORD=$(kubectl get secret -n ${NAMESPACE_MONITORING} monitoring-grafana -o jsonpath="{.data.admin-password}" | base64 -d)
    
    success "Monitoring Stack deployed"
    info "Grafana admin password: ${GRAFANA_PASSWORD}"
    info "Access Grafana: kubectl port-forward -n ${NAMESPACE_MONITORING} svc/monitoring-grafana 3000:80"
}

# Deploy Jenkins
deploy_jenkins() {
    info "Deploying Jenkins..."
    
    helm upgrade --install jenkins jenkins/jenkins \
        --namespace ${NAMESPACE_JENKINS} \
        -f helm/values/jenkins.yaml \
        --wait \
        --timeout 10m
    
    # Print Jenkins access info
    JENKINS_PASSWORD=$(kubectl get secret -n ${NAMESPACE_JENKINS} jenkins -o jsonpath="{.data.jenkins-admin-password}" | base64 -d 2>/dev/null || echo "Check jenkins values for password")
    
    success "Jenkins deployed"
    info "Jenkins admin password: ${JENKINS_PASSWORD}"
    info "Access Jenkins: kubectl port-forward -n ${NAMESPACE_JENKINS} svc/jenkins 8080:8080"
}

# Deploy ArgoCD
deploy_argocd() {
    info "Deploying ArgoCD..."
    
    helm upgrade --install argocd argo/argo-cd \
        --namespace ${NAMESPACE_ARGOCD} \
        --set server.service.type=LoadBalancer \
        --set configs.params."server\.insecure"=true \
        --wait \
        --timeout 10m
    
    # Get initial admin password
    ARGOCD_PASSWORD=$(kubectl get secret -n ${NAMESPACE_ARGOCD} argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "Secret not found")
    
    success "ArgoCD deployed"
    info "ArgoCD initial admin password: ${ARGOCD_PASSWORD}"
    info "Access ArgoCD: kubectl port-forward -n ${NAMESPACE_ARGOCD} svc/argocd-server 8443:443"
}

# Deploy Microservices
deploy_microservices() {
    local TAG="${1:-latest}"
    
    info "Deploying Microservices with tag: ${TAG}..."
    
    for SERVICE in user-service order-service product-service; do
        info "Deploying ${SERVICE}..."
        
        helm upgrade --install "${SERVICE}" helm/charts/microservice \
            --namespace ${NAMESPACE_MICROSERVICES} \
            -f "helm/values/${SERVICE}.yaml" \
            --set image.tag="${TAG}" \
            --wait \
            --timeout 5m
    done
    
    success "All microservices deployed"
}

# Deploy ArgoCD Applications (GitOps)
deploy_argocd_apps() {
    info "Deploying ArgoCD Applications..."
    
    # Apply ArgoCD projects
    kubectl apply -f argocd/projects/
    
    # Apply ArgoCD applications
    kubectl apply -f argocd/apps/
    
    success "ArgoCD Applications deployed"
    info "ArgoCD will now manage and sync all applications"
}

# Get deployment status
status() {
    info "=== Deployment Status ==="
    
    echo -e "\n${BLUE}Namespaces:${NC}"
    kubectl get namespaces | grep -E "(microservices|monitoring|jenkins|argocd|kube-system)"
    
    echo -e "\n${BLUE}Pods in microservices:${NC}"
    kubectl get pods -n ${NAMESPACE_MICROSERVICES} 2>/dev/null || echo "Namespace not found"
    
    echo -e "\n${BLUE}Pods in monitoring:${NC}"
    kubectl get pods -n ${NAMESPACE_MONITORING} 2>/dev/null || echo "Namespace not found"
    
    echo -e "\n${BLUE}Pods in jenkins:${NC}"
    kubectl get pods -n ${NAMESPACE_JENKINS} 2>/dev/null || echo "Namespace not found"
    
    echo -e "\n${BLUE}Pods in argocd:${NC}"
    kubectl get pods -n ${NAMESPACE_ARGOCD} 2>/dev/null || echo "Namespace not found"
    
    echo -e "\n${BLUE}Helm Releases:${NC}"
    helm list -A
}

# Cleanup / Uninstall all
cleanup() {
    warn "This will uninstall ALL deployed components!"
    read -p "Are you sure? (yes/no): " confirm
    
    if [[ "${confirm}" != "yes" ]]; then
        info "Aborted"
        exit 0
    fi
    
    info "Uninstalling all components..."
    
    # Uninstall microservices
    for SERVICE in user-service order-service product-service; do
        helm uninstall "${SERVICE}" -n ${NAMESPACE_MICROSERVICES} 2>/dev/null || true
    done
    
    # Uninstall platform components
    helm uninstall monitoring -n ${NAMESPACE_MONITORING} 2>/dev/null || true
    helm uninstall jenkins -n ${NAMESPACE_JENKINS} 2>/dev/null || true
    helm uninstall argocd -n ${NAMESPACE_ARGOCD} 2>/dev/null || true
    helm uninstall cluster-autoscaler -n kube-system 2>/dev/null || true
    helm uninstall aws-load-balancer-controller -n kube-system 2>/dev/null || true
    
    success "Cleanup completed"
}

# Print usage
usage() {
    cat << EOF
Usage: $0 <command> [options]

Commands:
    all             Deploy all platform components
    platform        Deploy platform components (ALB controller, autoscaler, monitoring)
    microservices   Deploy microservices only [TAG]
    jenkins         Deploy Jenkins only
    argocd          Deploy ArgoCD and applications
    status          Show deployment status
    cleanup         Uninstall all components
    help            Show this help message

Options:
    TAG             Image tag for microservices (default: latest)

Environment Variables:
    AWS_REGION      AWS region (default: us-east-1)
    CLUSTER_NAME    EKS cluster name (default: eks-platform-dev)

Examples:
    $0 all                          # Deploy everything
    $0 platform                     # Deploy platform only
    $0 microservices v1.2.3         # Deploy microservices with tag v1.2.3
    $0 status                       # Check status
    $0 cleanup                      # Remove everything
EOF
}

# Main entry point
main() {
    local COMMAND="${1:-help}"
    
    case "${COMMAND}" in
        all)
            check_prerequisites
            configure_kubectl
            add_helm_repos
            create_namespaces
            deploy_alb_controller
            deploy_cluster_autoscaler
            deploy_monitoring
            deploy_jenkins
            deploy_argocd
            deploy_microservices "${2:-latest}"
            deploy_argocd_apps
            status
            ;;
        platform)
            check_prerequisites
            configure_kubectl
            add_helm_repos
            create_namespaces
            deploy_alb_controller
            deploy_cluster_autoscaler
            deploy_monitoring
            ;;
        microservices)
            check_prerequisites
            configure_kubectl
            deploy_microservices "${2:-latest}"
            ;;
        jenkins)
            check_prerequisites
            configure_kubectl
            add_helm_repos
            create_namespaces
            deploy_jenkins
            ;;
        argocd)
            check_prerequisites
            configure_kubectl
            add_helm_repos
            create_namespaces
            deploy_argocd
            deploy_argocd_apps
            ;;
        status)
            configure_kubectl
            status
            ;;
        cleanup)
            configure_kubectl
            cleanup
            ;;
        help|*)
            usage
            ;;
    esac
}

main "$@"
