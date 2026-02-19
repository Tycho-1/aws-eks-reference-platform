# -----------------------------------------------------------------------------
# General
# -----------------------------------------------------------------------------

variable "name" {
  description = "Name prefix for all resources (cluster, VPC, etc.)."
  type        = string
}

variable "environment" {
  description = "Environment label (e.g. dev, staging, prod)."
  type        = string
  default     = "dev"
}

variable "tags" {
  description = "Additional tags to apply to all resources."
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zone names. If empty, a default of 2 AZs in the region is used."
  type        = list(string)
  default     = []
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (one per AZ). Leave default for auto calculation from vpc_cidr."
  type        = list(string)
  default     = []
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ). Leave default for auto calculation from vpc_cidr."
  type        = list(string)
  default     = []
}

variable "enable_nat_gateway" {
  description = "Enable NAT gateway for private subnets (single NAT to save cost, or one per AZ)."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT gateway for all AZs (cheaper) instead of one per AZ."
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# EKS Cluster
# -----------------------------------------------------------------------------

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster."
  type        = string
  default     = "1.34"
}

variable "cluster_endpoint_public_access" {
  description = "Whether the EKS API endpoint is publicly accessible."
  type        = bool
  default     = true
}

variable "cluster_endpoint_private_access" {
  description = "Whether the EKS API endpoint is accessible from within the VPC."
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# CNI
# -----------------------------------------------------------------------------

variable "cni_type" {
  description = "CNI to use: 'vpc-cni' (default AWS VPC CNI) or 'cilium'."
  type        = string
  default     = "vpc-cni"

  validation {
    condition     = contains(["vpc-cni", "cilium"], var.cni_type)
    error_message = "cni_type must be either 'vpc-cni' or 'cilium'."
  }
}

# -----------------------------------------------------------------------------
# Node group (default managed node group)
# -----------------------------------------------------------------------------

variable "enable_default_node_group" {
  description = "Create a default managed node group for the cluster."
  type        = bool
  default     = true
}

variable "node_group_instance_types" {
  description = "EC2 instance types for the default managed node group."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_group_desired_size" {
  description = "Desired number of nodes in the default node group."
  type        = number
  default     = 2
}

variable "node_group_min_size" {
  description = "Minimum number of nodes in the default node group."
  type        = number
  default     = 1
}

variable "node_group_max_size" {
  description = "Maximum number of nodes in the default node group."
  type        = number
  default     = 5
}

variable "node_group_disk_size" {
  description = "Root disk size in GB for nodes."
  type        = number
  default     = 50
}
