# Development Environment Configuration

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.24"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }

  # Uncomment and configure for remote state
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "eks-platform/dev/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "terraform"
    }
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

# Variables
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "eks-platform"
}

# Local values
locals {
  availability_zones = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]

  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
  database_subnet_cidrs = ["10.0.21.0/24", "10.0.22.0/24", "10.0.23.0/24"]

  # For dev, use smaller instances and single NAT gateway
  node_groups = {
    general = {
      desired_capacity = 2
      min_capacity     = 1
      max_capacity     = 5
      instance_types   = ["t3.medium"]
      capacity_type    = "ON_DEMAND"
      disk_size        = 50
      labels           = { workload = "general" }
      taints           = []
    }
    spot = {
      desired_capacity = 1
      min_capacity     = 0
      max_capacity     = 10
      instance_types   = ["t3.medium", "t3.large"]
      capacity_type    = "SPOT"
      disk_size        = 50
      labels           = { workload = "spot" }
      taints           = []
    }
  }
}

# VPC Module
module "vpc" {
  source = "../../modules/vpc"

  name        = var.project_name
  environment = var.environment

  vpc_cidr              = local.vpc_cidr
  availability_zones    = local.availability_zones
  public_subnet_cidrs   = local.public_subnet_cidrs
  private_subnet_cidrs  = local.private_subnet_cidrs
  database_subnet_cidrs = local.database_subnet_cidrs

  enable_nat_gateway = true
  single_nat_gateway = true  # Cost saving for dev

  tags = {
    Environment = var.environment
  }
}

# EKS Module
module "eks" {
  source = "../../modules/eks"

  name        = var.project_name
  environment = var.environment

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  kubernetes_version = "1.29"
  node_groups        = local.node_groups

  enable_cluster_autoscaler = true
  enable_external_dns       = true
  enable_alb_controller     = true

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  tags = {
    Environment = var.environment
  }
}

# RDS Module
module "rds" {
  source = "../../modules/rds"

  name        = var.project_name
  environment = var.environment

  vpc_id            = module.vpc.vpc_id
  subnet_group_name = module.vpc.database_subnet_group_name

  allowed_security_groups = [module.eks.cluster_security_group_id]

  engine_version    = "16.6"
  instance_class    = "db.t3.medium"
  allocated_storage = 20

  database_name   = "appdb"
  master_username = "dbadmin"

  multi_az            = false  # Cost saving for dev
  deletion_protection = false
  skip_final_snapshot = true

  tags = {
    Environment = var.environment
  }
}

# S3 Module
module "s3" {
  source = "../../modules/s3"

  name        = var.project_name
  environment = var.environment

  create_artifacts_bucket = true
  create_logs_bucket      = true
  force_destroy           = true  # For dev environment

  tags = {
    Environment = var.environment
  }
}

# ECR Repository for microservices
resource "aws_ecr_repository" "microservices" {
  for_each = toset(["user-service", "order-service", "product-service"])

  name                 = "${var.project_name}/${each.key}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Environment = var.environment
    Service     = each.key
  }
}

# ECR Lifecycle Policy
resource "aws_ecr_lifecycle_policy" "microservices" {
  for_each   = aws_ecr_repository.microservices
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Expire untagged images older than 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_oidc_provider_arn" {
  description = "EKS OIDC provider ARN"
  value       = module.eks.cluster_oidc_provider_arn
}

output "rds_endpoint" {
  description = "RDS endpoint"
  value       = module.rds.db_instance_endpoint
}

output "rds_credentials_secret_arn" {
  description = "RDS credentials secret ARN"
  value       = module.rds.db_credentials_secret_arn
}

output "artifacts_bucket_name" {
  description = "Artifacts S3 bucket name"
  value       = module.s3.artifacts_bucket_name
}

output "ecr_repository_urls" {
  description = "ECR repository URLs"
  value       = { for k, v in aws_ecr_repository.microservices : k => v.repository_url }
}

output "cluster_autoscaler_role_arn" {
  description = "Cluster autoscaler IAM role ARN"
  value       = module.eks.cluster_autoscaler_role_arn
}

output "alb_controller_role_arn" {
  description = "ALB controller IAM role ARN"
  value       = module.eks.alb_controller_role_arn
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"
}
