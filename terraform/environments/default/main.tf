# Example: EKS with default VPC CNI

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

module "eks_platform" {
  source = "../../modules/eks-platform"

  name        = var.name
  environment = var.environment

  vpc_cidr = var.vpc_cidr
  # availability_zones = ["eu-west-1a", "eu-west-1b"]  # optional

  kubernetes_version = var.kubernetes_version
  cni_type           = "vpc-cni" # default AWS VPC CNI

  enable_default_node_group  = var.enable_default_node_group
  node_group_instance_types = var.node_group_instance_types
  node_group_desired_size   = var.node_group_desired_size
  node_group_min_size       = var.node_group_min_size
  node_group_max_size       = var.node_group_max_size
  node_group_disk_size      = var.node_group_disk_size

  tags = merge(var.tags, { "Project" = var.project_tag })
}
