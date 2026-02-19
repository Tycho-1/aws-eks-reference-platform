# Example: EKS with Cilium CNI and Karpenter

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

# ECR Public GetAuthorizationToken API is only available in us-east-1 (AWS design: global service, single API endpoint)
provider "aws" {
  alias   = "ecr"
  region  = "us-east-1"
  profile = var.aws_profile
}

# Helm provider must connect to the EKS cluster (created by the module)
provider "helm" {
  kubernetes = {
    host                   = module.eks_cilium_karpenter.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_cilium_karpenter.cluster_certificate_authority_data)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks_cilium_karpenter.cluster_name, "--region", var.aws_region]
    }
  }
}

module "eks_cilium_karpenter" {
  source = "../../modules/eks-cilium-karpenter"

  providers = {
    aws      = aws
    aws.ecr  = aws.ecr
  }

  name        = var.name
  environment = var.environment

  vpc_cidr                 = var.vpc_cidr
  create_database_subnets  = var.create_rds_postgres
  kubernetes_version       = var.kubernetes_version
  karpenter_node_desired_size = var.karpenter_node_desired_size
  karpenter_node_min_size     = var.karpenter_node_min_size
  karpenter_node_max_size     = var.karpenter_node_max_size
  install_karpenter_helm      = var.install_karpenter_helm
  karpenter_helm_chart_version = var.karpenter_helm_chart_version
  cilium_egress_masquerade_interfaces  = var.cilium_egress_masquerade_interfaces
  cilium_cluster_pool_ipv4_cidr       = var.cilium_cluster_pool_ipv4_cidr
  cilium_encryption_enabled           = var.cilium_encryption_enabled
  cilium_hubble_enabled              = var.cilium_hubble_enabled
  cilium_prometheus_service_monitor_enabled = var.cilium_prometheus_service_monitor_enabled
  cilium_clustermesh_enabled                = var.cilium_clustermesh_enabled
  cilium_cluster_name                      = var.cilium_cluster_name
  cilium_cluster_id                        = var.cilium_cluster_id
  cilium_clustermesh_peer_pod_cidrs        = var.cilium_clustermesh_peer_pod_cidrs

  tags = merge(var.tags, { "Project" = var.project_tag })
}

# CoreDNS patch for Cilium kube-proxy replacement is now handled inside the module
# (null_resource.coredns_cilium_patch) so it runs during addon creation.
