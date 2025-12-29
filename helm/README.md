# Helm Charts Directory

This directory contains all Helm charts and values files for the EKS Platform.

## Directory Structure

```
helm/
├── charts/
│   └── microservice/       # Generic reusable chart for all microservices
│       ├── Chart.yaml
│       ├── values.yaml     # Default values
│       └── templates/
│           ├── _helpers.tpl
│           ├── deployment.yaml
│           ├── service.yaml
│           ├── serviceaccount.yaml
│           ├── hpa.yaml
│           ├── ingress.yaml
│           ├── networkpolicy.yaml
│           └── pdb.yaml
└── values/
    ├── user-service.yaml           # Service-specific overrides
    ├── order-service.yaml
    ├── product-service.yaml
    ├── jenkins.yaml                # Official Jenkins chart values
    ├── monitoring.yaml             # kube-prometheus-stack values
    ├── aws-load-balancer-controller.yaml
    └── cluster-autoscaler.yaml
```

## Usage

### Deploy a Microservice

```bash
# Deploy user-service
helm upgrade --install user-service ./charts/microservice \
    --namespace microservices \
    -f values/user-service.yaml \
    --set image.tag=v1.0.0

# Deploy all microservices
for service in user-service order-service product-service; do
    helm upgrade --install $service ./charts/microservice \
        --namespace microservices \
        -f values/${service}.yaml
done
```

### Deploy Platform Components

```bash
# Add Helm repos (one time)
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add jenkins https://charts.jenkins.io
helm repo add eks https://aws.github.io/eks-charts
helm repo add autoscaler https://kubernetes.github.io/autoscaler
helm repo update

# Deploy Monitoring Stack
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
    --namespace monitoring \
    --create-namespace \
    -f values/monitoring.yaml

# Deploy Jenkins
helm upgrade --install jenkins jenkins/jenkins \
    --namespace jenkins \
    --create-namespace \
    -f values/jenkins.yaml

# Deploy AWS Load Balancer Controller
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
    --namespace kube-system \
    -f values/aws-load-balancer-controller.yaml

# Deploy Cluster Autoscaler
helm upgrade --install cluster-autoscaler autoscaler/cluster-autoscaler \
    --namespace kube-system \
    -f values/cluster-autoscaler.yaml
```

### Check Releases

```bash
# List all releases
helm list -A

# Check release status
helm status user-service -n microservices

# View rendered manifests
helm template user-service ./charts/microservice -f values/user-service.yaml
```

### Rollback

```bash
# View release history
helm history user-service -n microservices

# Rollback to previous version
helm rollback user-service -n microservices

# Rollback to specific revision
helm rollback user-service 2 -n microservices
```

## Chart Customization

### Microservice Chart

The generic microservice chart supports these main configurations:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of replicas | `2` |
| `image.repository` | Image repository | `""` |
| `image.tag` | Image tag | `latest` |
| `service.port` | Service port | `80` |
| `resources.limits.cpu` | CPU limit | `500m` |
| `resources.limits.memory` | Memory limit | `512Mi` |
| `autoscaling.enabled` | Enable HPA | `true` |
| `autoscaling.minReplicas` | Min replicas | `2` |
| `autoscaling.maxReplicas` | Max replicas | `10` |
| `ingress.enabled` | Enable Ingress | `true` |
| `networkPolicy.enabled` | Enable Network Policy | `true` |

### Override Values

Create service-specific values files to override defaults:

```yaml
# values/my-service.yaml
fullnameOverride: "my-service"

image:
  repository: 123456789.dkr.ecr.us-east-1.amazonaws.com/my-service
  tag: "v1.0.0"

resources:
  limits:
    cpu: 1000m
    memory: 1Gi

autoscaling:
  maxReplicas: 20
```

## ArgoCD Integration

ArgoCD applications are configured to use these Helm charts:

```yaml
# argocd/apps/microservices.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
spec:
  source:
    path: helm/charts/microservice
    helm:
      valueFiles:
        - ../../values/user-service.yaml
```

ArgoCD will automatically sync when values files are updated in Git.

## CI/CD Integration

The Jenkins pipeline is configured to:

1. Build Docker images
2. Update Helm values files with new image tags
3. Push changes to Git
4. ArgoCD auto-syncs the deployment

See `Jenkinsfile` for the complete CI/CD workflow.
