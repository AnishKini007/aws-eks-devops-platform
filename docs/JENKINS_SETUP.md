# Jenkins Setup Guide for EKS Platform

## Overview

This guide covers setting up Jenkins as the primary CI/CD tool on your EKS cluster. GitHub Actions remains available as a backup.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    CI/CD Pipeline Flow                          │
│                                                                 │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐ │
│  │  GitHub  │───▶│ Jenkins  │───▶│   ECR    │───▶│  ArgoCD  │ │
│  │  (Code)  │    │  (CI)    │    │ (Images) │    │  (CD)    │ │
│  └──────────┘    └──────────┘    └──────────┘    └──────────┘ │
│       │                                               │        │
│       │         GitHub Actions (Backup)               │        │
│       └───────────────────────────────────────────────┘        │
└─────────────────────────────────────────────────────────────────┘
```

## Prerequisites

1. EKS cluster running
2. kubectl configured
3. ArgoCD installed

## Installation

### Option 1: Deploy via ArgoCD (Recommended)

```bash
# Apply Jenkins ArgoCD application
kubectl apply -f argocd/apps/jenkins.yaml

# Wait for deployment
kubectl -n jenkins rollout status deployment/jenkins
```

### Option 2: Deploy Manually

```bash
# Create namespace and apply manifests
kubectl apply -f kubernetes/platform/jenkins/

# Wait for deployment
kubectl -n jenkins rollout status deployment/jenkins
```

## Initial Setup

### 1. Get Admin Password

```bash
# Get initial admin password
kubectl -n jenkins exec -it $(kubectl -n jenkins get pods -l app=jenkins -o jsonpath='{.items[0].metadata.name}') -- cat /var/jenkins_home/secrets/initialAdminPassword
```

### 2. Access Jenkins UI

```bash
# Port forward (for local access)
kubectl port-forward -n jenkins svc/jenkins 8080:8080

# Access at: http://localhost:8080/jenkins
```

### 3. Configure Credentials

Add these credentials in Jenkins (Manage Jenkins → Credentials):

| ID | Type | Description |
|----|------|-------------|
| `aws-credentials` | Username/Password | AWS Access Key ID / Secret |
| `aws-account-id` | Secret text | AWS Account ID |
| `github-credentials` | Username/Password | GitHub username / PAT |

### 4. Install Required Plugins

The following plugins should be installed:
- Kubernetes
- Pipeline
- Git
- Docker Pipeline
- Configuration as Code (JCasC)
- AWS Steps
- Blue Ocean (optional, for better UI)

## Pipeline Jobs

### Microservices CI Pipeline

- **Location**: `Jenkinsfile` (root)
- **Triggers**: On push to main/develop
- **Stages**:
  1. Checkout
  2. Detect Changes
  3. Lint & Test
  4. Security Scan (Source)
  5. Build & Push Images
  6. Security Scan (Images)
  7. Update Manifests
  8. Deploy (triggers ArgoCD)

### Terraform Infrastructure Pipeline

- **Location**: `jenkins/Jenkinsfile.terraform`
- **Triggers**: Manual
- **Parameters**:
  - ENVIRONMENT: dev/staging/prod
  - ACTION: plan/apply/destroy
  - AUTO_APPROVE: true/false

## Running Pipelines

### Build All Services

```
Jenkins → microservices-ci → Build with Parameters
  SERVICE: all
  SKIP_TESTS: false
  DEPLOY_TO_EKS: true
```

### Build Single Service

```
Jenkins → microservices-ci → Build with Parameters
  SERVICE: user-service
  SKIP_TESTS: false
  DEPLOY_TO_EKS: true
```

### Deploy Infrastructure

```
Jenkins → terraform-infrastructure → Build with Parameters
  ENVIRONMENT: dev
  ACTION: apply
  AUTO_APPROVE: false
```

## GitHub Actions (Backup)

GitHub Actions workflows are retained as backup in `.github/workflows/`:

- `ci.yml` - Microservices CI (disabled by default)
- `terraform.yml` - Infrastructure deployment

### Enable GitHub Actions Backup

To use GitHub Actions as backup, either:

1. **Manual trigger**: Go to Actions tab → Select workflow → Run workflow
2. **Remove condition**: Edit workflow files to trigger on push

### When to Use Backup

- Jenkins is down/unavailable
- Emergency deployments needed
- Testing workflow changes

## Webhook Configuration

### GitHub Webhook

1. Go to GitHub repo → Settings → Webhooks
2. Add webhook:
   - URL: `https://your-jenkins-url/jenkins/github-webhook/`
   - Content type: `application/json`
   - Events: Push, Pull Request

## Troubleshooting

### Jenkins Pod Not Starting

```bash
# Check pod status
kubectl -n jenkins describe pod -l app=jenkins

# Check logs
kubectl -n jenkins logs -l app=jenkins
```

### Pipeline Failing to Build Docker

```bash
# Ensure docker socket is mounted
kubectl -n jenkins exec -it <pod> -c docker -- docker version
```

### Cannot Push to ECR

```bash
# Verify AWS credentials in Jenkins
# Check ECR repository exists
aws ecr describe-repositories --repository-names eks-platform/user-service
```

## Monitoring Jenkins

Jenkins metrics can be scraped by Prometheus:

```yaml
# Add to prometheus config
- job_name: 'jenkins'
  metrics_path: /jenkins/prometheus/
  static_configs:
    - targets: ['jenkins.jenkins.svc.cluster.local:8080']
```

## Security Best Practices

1. **Change default password** immediately after setup
2. **Use RBAC** for Jenkins users
3. **Store secrets** in Jenkins credentials, not in code
4. **Enable HTTPS** via ALB/Ingress
5. **Regular updates** of Jenkins and plugins
6. **Audit logging** enabled

## Backup & Recovery

### Backup Jenkins Home

```bash
# Create backup
kubectl -n jenkins exec -it <jenkins-pod> -- tar czf /tmp/jenkins-backup.tar.gz /var/jenkins_home

# Copy to local
kubectl cp jenkins/<jenkins-pod>:/tmp/jenkins-backup.tar.gz ./jenkins-backup.tar.gz
```

### Restore from Backup

```bash
# Copy backup to pod
kubectl cp ./jenkins-backup.tar.gz jenkins/<jenkins-pod>:/tmp/

# Restore
kubectl -n jenkins exec -it <jenkins-pod> -- tar xzf /tmp/jenkins-backup.tar.gz -C /
```
