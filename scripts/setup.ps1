# PowerShell setup script for Windows users

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  AWS EKS Platform Setup Script" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# Check prerequisites
function Check-Prerequisites {
    Write-Host "Checking prerequisites..." -ForegroundColor Yellow
    
    $missing = @()
    
    if (!(Get-Command aws -ErrorAction SilentlyContinue)) {
        $missing += "AWS CLI"
    }
    
    if (!(Get-Command terraform -ErrorAction SilentlyContinue)) {
        $missing += "Terraform"
    }
    
    if (!(Get-Command kubectl -ErrorAction SilentlyContinue)) {
        $missing += "kubectl"
    }
    
    if (!(Get-Command helm -ErrorAction SilentlyContinue)) {
        $missing += "Helm"
    }
    
    if (!(Get-Command docker -ErrorAction SilentlyContinue)) {
        $missing += "Docker"
    }
    
    if ($missing.Count -gt 0) {
        Write-Host "Missing prerequisites: $($missing -join ', ')" -ForegroundColor Red
        Write-Host "Please install them before continuing." -ForegroundColor Red
        exit 1
    }
    
    Write-Host "All prerequisites are installed!" -ForegroundColor Green
}

# Deploy infrastructure
function Deploy-Infrastructure {
    Write-Host "Deploying infrastructure with Terraform..." -ForegroundColor Yellow
    
    Push-Location terraform/environments/dev
    
    terraform init
    terraform plan -out=tfplan
    
    $confirm = Read-Host "Do you want to apply this plan? (y/n)"
    if ($confirm -eq 'y' -or $confirm -eq 'Y') {
        terraform apply tfplan
    } else {
        Write-Host "Deployment cancelled." -ForegroundColor Yellow
        Pop-Location
        exit 0
    }
    
    Pop-Location
    Write-Host "Infrastructure deployed successfully!" -ForegroundColor Green
}

# Configure kubectl
function Configure-Kubectl {
    Write-Host "Configuring kubectl..." -ForegroundColor Yellow
    
    Push-Location terraform/environments/dev
    $clusterName = terraform output -raw eks_cluster_name
    Pop-Location
    
    aws eks update-kubeconfig --name $clusterName --region us-east-1
    
    Write-Host "kubectl configured successfully!" -ForegroundColor Green
}

# Deploy ArgoCD
function Deploy-ArgoCD {
    Write-Host "Deploying ArgoCD..." -ForegroundColor Yellow
    
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    
    Write-Host "Waiting for ArgoCD to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
    
    Write-Host "ArgoCD deployed successfully!" -ForegroundColor Green
    Write-Host "ArgoCD admin password:" -ForegroundColor Cyan
    $password = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}"
    [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($password))
}

# Deploy applications
function Deploy-Applications {
    Write-Host "Deploying platform applications via ArgoCD..." -ForegroundColor Yellow
    
    kubectl apply -f argocd/projects/
    kubectl apply -f argocd/apps/
    
    Write-Host "Applications deployed successfully!" -ForegroundColor Green
}

# Main menu
function Main {
    Check-Prerequisites
    
    Write-Host ""
    Write-Host "Select an option:"
    Write-Host "1) Deploy everything (infrastructure + applications)"
    Write-Host "2) Deploy infrastructure only"
    Write-Host "3) Configure kubectl only"
    Write-Host "4) Deploy ArgoCD only"
    Write-Host "5) Deploy applications only"
    Write-Host "6) Exit"
    
    $choice = Read-Host "Enter your choice (1-6)"
    
    switch ($choice) {
        "1" {
            Deploy-Infrastructure
            Configure-Kubectl
            Deploy-ArgoCD
            Deploy-Applications
        }
        "2" { Deploy-Infrastructure }
        "3" { Configure-Kubectl }
        "4" { Deploy-ArgoCD }
        "5" { Deploy-Applications }
        "6" { exit 0 }
        default {
            Write-Host "Invalid option" -ForegroundColor Red
            exit 1
        }
    }
    
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host "  Setup Complete!" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Green
}

Main
