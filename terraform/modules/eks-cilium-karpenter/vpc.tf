# -----------------------------------------------------------------------------
# VPC and subnets for EKS (public + private). Private subnets tagged for Karpenter discovery.
# -----------------------------------------------------------------------------

data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  cluster_name    = "${var.name}-${var.environment}"
  azs             = length(var.availability_zones) > 0 ? var.availability_zones : slice(data.aws_availability_zones.available.names, 0, 2)
  vpc_octets      = [for s in split(".", split("/", var.vpc_cidr)[0]) : tonumber(s)]
  vpc_prefix      = tonumber(split("/", var.vpc_cidr)[1])
  private_cidrs   = length(var.private_subnet_cidrs) > 0 ? var.private_subnet_cidrs : [for i, az in local.azs : "10.0.${1 + i}.0/24"]
  public_cidrs    = length(var.public_subnet_cidrs) > 0 ? var.public_subnet_cidrs : [for i, az in local.azs : "10.0.${100 + 1 + i}.0/24"]
  database_cidrs  = length(var.database_subnet_cidrs) > 0 ? var.database_subnet_cidrs : [for i, az in local.azs : "10.0.${11 + i}.0/24"]
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.cluster_name
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = local.private_cidrs
  public_subnets  = local.public_cidrs
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
