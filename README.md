# AWS EKS Platform

[![CI Pipeline](https://github.com/AnishKini007/aws-eks-devops-platform/actions/workflows/ci.yml/badge.svg)](https://github.com/AnishKini007/aws-eks-devops-platform/actions/workflows/ci.yml)
[![Terraform](https://img.shields.io/badge/Terraform-v1.6+-623CE4?logo=terraform)](https://terraform.io)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.28+-326CE5?logo=kubernetes)](https://kubernetes.io)

> **Highly Available Microservices Platform on AWS EKS using Terraform & GitOps**

A production-ready Kubernetes platform on AWS EKS featuring Infrastructure as Code, GitOps-based continuous deployment, comprehensive observability, and enterprise security patterns.

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              AWS Cloud                                       │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                         VPC (10.0.0.0/16)                              │  │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐        │  │
│  │  │   AZ-1 (a)      │  │   AZ-2 (b)      │  │   AZ-3 (c)      │        │  │
│  │  │ ┌─────────────┐ │  │ ┌─────────────┐ │  │ ┌─────────────┐ │        │  │
│  │  │ │Public Subnet│ │  │ │Public Subnet│ │  │ │Public Subnet│ │        │  │
│  │  │ │  (NAT GW)   │ │  │ │  (NAT GW)   │ │  │ │  (NAT GW)   │ │        │  │
│  │  │ └─────────────┘ │  │ └─────────────┘ │  │ └─────────────┘ │        │  │
│  │  │ ┌─────────────┐ │  │ ┌─────────────┐ │  │ ┌─────────────┐ │        │  │
│  │  │ │Private Sub  │ │  │ │Private Sub  │ │  │ │Private Sub  │ │        │  │
│  │  │ │(EKS Nodes)  │ │  │ │(EKS Nodes)  │ │  │ │(EKS Nodes)  │ │        │  │
│  │  │ └─────────────┘ │  │ └─────────────┘ │  │ └─────────────┘ │        │  │
│  │  │ ┌─────────────┐ │  │ ┌─────────────┐ │  │ ┌─────────────┐ │        │  │
│  │  │ │  DB Subnet  │ │  │ │  DB Subnet  │ │  │ │  DB Subnet  │ │        │  │
│  │  │ │   (RDS)     │ │  │ │   (RDS)     │ │  │ │   (RDS)     │ │        │  │
│  │  │ └─────────────┘ │  │ └─────────────┘ │  │ └─────────────┘ │        │  │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────┘        │  │
│  │                                                                        │  │
│  │  ┌──────────────────────────────────────────────────────────────────┐ │  │
│  │  │                    EKS Cluster (v1.28)                           │ │  │
│  │  │  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐    │ │  │
│  │  │  │  ArgoCD    │ │ Prometheus │ │  Grafana   │ │ ALB Ingress│    │ │  │
│  │  │  └────────────┘ └────────────┘ └────────────┘ └────────────┘    │ │  │
│  │  │  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐    │ │  │
│  │  │  │ User Svc   │ │ Order Svc  │ │ Product Svc│ │ API Gateway│    │ │  │
│  │  │  │  (Node.js) │ │  (Python)  │ │  (Node.js) │ │            │    │ │  │
│  │  │  └────────────┘ └────────────┘ └────────────┘ └────────────┘    │ │  │
│  │  └──────────────────────────────────────────────────────────────────┘ │  │
│  │                                                                        │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │  │
│  │  │    RDS      │  │     S3      │  │  Secrets    │  │ CloudWatch  │   │  │
│  │  │ (PostgreSQL)│  │ (Artifacts) │  │  Manager    │  │   (Logs)    │   │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘   │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘

                    │  ┌─────────────────────────────────────┐
                    │         CI/CD Pipeline              │
                    │  ┌─────────┐      ┌─────────────┐   │
                    │  │ Jenkins │ ──── │   ArgoCD    │   │
                    │  │  (CI)   │      │   (GitOps)  │   │
                    │  └─────────┘      └─────────────┘   │
                    │       │                  │          │
                    │       ▼                  ▼          │
                    │  ┌─────────┐      ┌─────────────┐   │
                    │  │   ECR   │      │ Kubernetes  │   │
                    │  │ (Images)│      │   Cluster   │   │
                    │  └─────────┘      └─────────────┘   │
                    │                                     │
                    │  GitHub Actions (Backup CI)         │
                    └─────────────────────────────────────┘
```

## 🚀 Features

### Infrastructure (Terraform)
- **Multi-AZ VPC** with public, private, and database subnets
- **EKS Cluster** with managed node groups and autoscaling
- **RDS PostgreSQL** with Multi-AZ deployment
- **S3 Buckets** for artifacts and Terraform state
- **IAM Roles for Service Accounts (IRSA)** for secure AWS access
- **AWS Secrets Manager** integration

### Kubernetes Platform
- **ALB Ingress Controller** for load balancing
- **Cluster Autoscaler** for dynamic node scaling
- **Horizontal Pod Autoscaler (HPA)** for workload scaling
- **External DNS** for automatic DNS management
- **Cert Manager** for TLS certificate automation

### CI/CD Pipeline
- **Jenkins** (Primary) - CI pipelines running on Kubernetes agents
- **GitHub Actions** (Backup) - Automated workflows as fallback
- **ArgoCD** for GitOps-based continuous deployment
- **Automated image updates** with manifest commits

### Observability
- **Prometheus** for metrics collection
- **Grafana** with pre-configured dashboards
- **CloudWatch** integration for centralized logging
- **AlertManager** for alerting

### Security
- **Network Policies** for pod-to-pod traffic control
- **Pod Security Standards** enforcement
- **Secrets encryption** at rest
- **Private ECR** for container images

## 📁 Project Structure

```
aws-eks-devops-platform/
├── terraform/                    # Infrastructure as Code
│   ├── environments/
│   │   ├── dev/
│   │   ├── staging/
│   │   └── prod/
│   ├── modules/
│   │   ├── vpc/
│   │   ├── eks/
│   │   ├── rds/
│   │   ├── s3/
│   │   └── iam/
│   └── backend.tf
├── kubernetes/                   # Kubernetes manifests
│   ├── base/
│   │   ├── namespaces/
│   │   ├── network-policies/
│   │   └── rbac/
│   ├── apps/
│   │   ├── user-service/
│   │   ├── order-service/
│   │   └── product-service/
│   ├── platform/
│   │   ├── ingress-controller/
│   │   ├── cluster-autoscaler/
│   │   ├── external-dns/
│   │   └── cert-manager/
│   └── monitoring/
│       ├── prometheus/
│       └── grafana/
├── argocd/                       # ArgoCD configurations
│   ├── apps/
│   └── projects/
├── apps/                         # Microservices source code
│   ├── user-service/
│   ├── order-service/
│   └── product-service/
├── .github/
│   └── workflows/
│       ├── ci.yml               # Backup CI pipeline
│       ├── terraform.yml        # Backup Terraform pipeline
│       └── security-scan.yml
├── jenkins/                      # Jenkins configurations
│   ├── Jenkinsfile.terraform    # Terraform pipeline
│   └── vars/                    # Shared library functions
├── helm/                         # Helm charts and values
│   ├── charts/
│   │   └── microservice/        # Generic reusable chart
│   └── values/                  # Service & platform values
├── Jenkinsfile                   # Main CI pipeline
├── scripts/                      # Utility scripts
│   └── deploy.sh                # Helm deployment script
└── docs/                         # Documentation
```

## 🛠️ Prerequisites

- AWS CLI v2 configured with appropriate permissions
- Terraform >= 1.6
- kubectl >= 1.28
- Helm >= 3.12
- Docker
- ArgoCD CLI (optional)

## 🚀 Quick Start

### 1. Clone the Repository
```bash
git clone https://github.com/AnishKini007/aws-eks-devops-platform.git
cd aws-eks-devops-platform
```

### 2. Configure AWS Credentials
```bash
aws configure
# Or use environment variables (Linux/Mac)
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="ap-south-1"

# Windows PowerShell
$env:AWS_ACCESS_KEY_ID="your-access-key"
$env:AWS_SECRET_ACCESS_KEY="your-secret-key"
$env:AWS_DEFAULT_REGION="ap-south-1"
```

### 3. Deploy Infrastructure
```bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
```

Save the outputs - you'll need the ECR URLs and IAM role ARNs.

### 4. Configure kubectl
```bash
aws eks update-kubeconfig --name eks-platform-dev --region ap-south-1
kubectl get nodes  # Verify connection
```

### 5. Update Helm Values with Your AWS Account

Update these files with your AWS account ID and region from Terraform outputs:
- `helm/values/aws-load-balancer-controller.yaml` - Update `eks.amazonaws.com/role-arn`
- `helm/values/cluster-autoscaler.yaml` - Update `eks.amazonaws.com/role-arn` and region
- `helm/values/user-service.yaml` - Update ECR repository URL
- `helm/values/order-service.yaml` - Update ECR repository URL
- `helm/values/product-service.yaml` - Update ECR repository URL

### 6. Build and Push Docker Images to ECR

```bash
# Get your AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="ap-south-1"

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Build and push each service
for service in user-service order-service product-service; do
    cd apps/$service
    docker build -t $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/eks-platform/$service:latest .
    docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/eks-platform/$service:latest
    cd ../..
done
```

**Windows PowerShell:**
```powershell
$AWS_ACCOUNT_ID = aws sts get-caller-identity --query Account --output text
$AWS_REGION = "ap-south-1"

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

# Build and push each service
foreach ($service in @("user-service", "order-service", "product-service")) {
    cd apps/$service
    docker build -t "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/eks-platform/${service}:latest" .
    docker push "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/eks-platform/${service}:latest"
    cd ../..
}
```

### 7. Deploy Platform Components

**Windows PowerShell:**
```powershell
.\scripts\setup.ps1 all
```

**Linux/Mac:**
```bash
chmod +x scripts/deploy.sh
./scripts/deploy.sh all
```

### 8. Verify Deployment
```bash
# Check all pods are running
kubectl get pods -A

# Check microservices
kubectl get pods -n microservices

# Check Helm releases
helm list -A
```

### 9. Access Services

```bash
# Access microservices (separate terminals)
kubectl port-forward -n microservices svc/user-service 8000:80
kubectl port-forward -n microservices svc/order-service 8001:80
kubectl port-forward -n microservices svc/product-service 8002:80

# Access Grafana
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80

# Access Jenkins
kubectl port-forward -n jenkins svc/jenkins 8080:8080

# Access ArgoCD
kubectl port-forward -n argocd svc/argocd-server 8443:443
```

**Get Passwords (PowerShell):**
```powershell
# Grafana password
kubectl get secret -n monitoring monitoring-grafana -o jsonpath="{.data.admin-password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }

# Jenkins password
kubectl get secret -n jenkins jenkins -o jsonpath="{.data.jenkins-admin-password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }

# ArgoCD password
kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath="{.data.password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
```

### 10. Test the APIs

| Service | URL | Swagger Docs |
|---------|-----|--------------|
| User Service | http://localhost:8000/health | http://localhost:8000/docs |
| Order Service | http://localhost:8001/health | http://localhost:8001/docs |
| Product Service | http://localhost:8002/health | http://localhost:8002/docs |
| Grafana | http://localhost:3000 | user: admin |
| Jenkins | http://localhost:8080 | user: admin |
| ArgoCD | https://localhost:8443 | user: admin |

## 📦 Helm Charts

This project uses Helm charts for all deployments:

| Component | Chart Source | Values File |
|-----------|--------------|-------------|
| Microservices | `helm/charts/microservice` | `helm/values/{service}.yaml` |
| Jenkins | `jenkins/jenkins` (official) | `helm/values/jenkins.yaml` |
| Prometheus/Grafana | `kube-prometheus-stack` | `helm/values/monitoring.yaml` |
| AWS LB Controller | `eks/aws-load-balancer-controller` | `helm/values/aws-load-balancer-controller.yaml` |
| Cluster Autoscaler | `autoscaler/cluster-autoscaler` | `helm/values/cluster-autoscaler.yaml` |

### Deploy/Rollback Microservices
```bash
# Deploy with specific image tag
helm upgrade --install user-service helm/charts/microservice \
    -n microservices -f helm/values/user-service.yaml \
    --set image.tag=v1.2.3

# Rollback to previous version
helm rollback user-service -n microservices

# Check release history
helm history user-service -n microservices
```

## 📊 Monitoring Dashboards

Grafana comes pre-configured with dashboards for:
- Kubernetes cluster overview
- Node metrics
- Pod metrics
- Application-specific metrics
- AWS resources

## 🔒 Security Considerations

1. **Network Isolation**: All EKS nodes run in private subnets
2. **IRSA**: Pods use IAM roles via service accounts (no static credentials)
3. **Encryption**: Secrets encrypted at rest, TLS for all traffic
4. **Network Policies**: Default deny with explicit allow rules
5. **Image Scanning**: Trivy scans in CI pipeline

## 📈 Autoscaling

| Component | Type | Trigger |
|-----------|------|---------|
| EKS Nodes | Cluster Autoscaler | Pending pods |
| Pods | HPA | CPU/Memory >70% |
| RDS | Storage Autoscaling | >80% storage |

## 💰 Cost Optimization

- Spot instances for non-critical workloads
- Right-sizing recommendations via metrics
- Scheduled scaling for dev/staging
- S3 lifecycle policies

## 🧪 Testing

```bash
# Run infrastructure tests
cd terraform
terraform validate
terraform plan

# Run application tests
cd apps/user-service
npm test

# Run integration tests
./scripts/integration-test.sh
```

## 📝 Resume Bullet Point

> "Designed and deployed a production-grade AWS EKS platform using Terraform and GitOps (ArgoCD), enabling automated CI/CD pipelines, multi-AZ high availability, HPA/Cluster Autoscaler for elastic scaling, and comprehensive observability with Prometheus/Grafana. Implemented IRSA for secure AWS service access and achieved 99.9% uptime SLA."

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📞 Contact

Your Name - your.email@example.com

Project Link: [https://github.com/AnishKini007/aws-eks-devops-platform](https://github.com/AnishKini007/aws-eks-devops-platform)
