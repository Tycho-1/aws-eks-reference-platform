# -----------------------------------------------------------------------------
# VPC and subnets for EKS (public + private across AZs)
# -----------------------------------------------------------------------------

data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = length(var.availability_zones) > 0 ? var.availability_zones : slice(data.aws_availability_zones.available.names, 0, 2)
  # Derive private/public CIDRs from vpc_cidr if not provided
  vpc_octets = [for s in split(".", split("/", var.vpc_cidr)[0]) : tonumber(s)]
  vpc_prefix = tonumber(split("/", var.vpc_cidr)[1])
  # e.g. 10.0.0.0/16 -> private 10.0.1.0/24, 10.0.2.0/24; public 10.0.101.0/24, 10.0.102.0/24
  private_cidrs = length(var.private_subnet_cidrs) > 0 ? var.private_subnet_cidrs : [for i, az in local.azs : "10.0.${1 + i}.0/24"]
  public_cidrs  = length(var.public_subnet_cidrs) > 0 ? var.public_subnet_cidrs : [for i, az in local.azs : "10.0.${100 + 1 + i}.0/24"]
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.name}-${var.environment}"
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = local.private_cidrs
  public_subnets  = local.public_cidrs

  enable_nat_gateway   = var.enable_nat_gateway
  single_nat_gateway   = var.single_nat_gateway
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = merge(var.tags, {
    "terraform"   = "true"
    "environment" = var.environment
  })
}
