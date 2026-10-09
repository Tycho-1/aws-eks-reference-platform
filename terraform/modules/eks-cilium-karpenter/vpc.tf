# -----------------------------------------------------------------------------
# VPC: private subnets for EKS nodes; public subnets only for NAT (egress). Not public workloads.
# Private subnets tagged for Karpenter discovery.
# -----------------------------------------------------------------------------

data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  cluster_name = "${var.name}-${var.environment}"
  azs          = length(var.availability_zones) > 0 ? var.availability_zones : slice(data.aws_availability_zones.available.names, 0, 2)
  # /24s carved from vpc_cidr (assumes a /16), e.g. 10.0.0.0/16 -> private 10.0.1-2.0/24,
  # database 10.0.11-12.0/24, public 10.0.101-102.0/24
  private_cidrs  = length(var.private_subnet_cidrs) > 0 ? var.private_subnet_cidrs : [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 8, 1 + i)]
  public_cidrs   = length(var.public_subnet_cidrs) > 0 ? var.public_subnet_cidrs : [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 8, 101 + i)]
  database_cidrs = length(var.database_subnet_cidrs) > 0 ? var.database_subnet_cidrs : [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 8, 11 + i)]
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.cluster_name
  cidr = var.vpc_cidr

  azs              = local.azs
  private_subnets  = local.private_cidrs
  public_subnets   = local.public_cidrs
  database_subnets = var.create_database_subnets ? local.database_cidrs : []

  create_database_subnet_group       = var.create_database_subnets
  create_database_subnet_route_table = var.create_database_subnets

  enable_nat_gateway   = var.enable_nat_gateway
  single_nat_gateway   = var.single_nat_gateway
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
    # Required for Karpenter to discover subnets for node launch
    "karpenter.sh/discovery" = local.cluster_name
  }

  tags = merge(var.tags, {
    "terraform"   = "true"
    "environment" = var.environment
  })
}
