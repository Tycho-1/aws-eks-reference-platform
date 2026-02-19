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

variable "create_database_subnets" {
  description = "Create database subnets and subnet group (for RDS). Set true when using RDS. Default false — no extra resources when RDS is not used."
  type        = bool
  default     = false
}

variable "database_subnet_cidrs" {
  description = "CIDR blocks for database subnets (one per AZ, for RDS). Default 10.0.11.0/24, 10.0.12.0/24. Only used when create_database_subnets = true."
  type        = list(string)
  default     = []
}

variable "enable_nat_gateway" {
  description = "Enable NAT gateway for private subnets."
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
# Karpenter system node group (runs Karpenter controller; not managed by Karpenter)
# -----------------------------------------------------------------------------

variable "karpenter_node_instance_types" {
  description = "Instance types for the Karpenter system node group."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "karpenter_node_desired_size" {
  description = "Desired number of nodes in the Karpenter system node group."
  type        = number
  default     = 2
}

variable "karpenter_node_min_size" {
  description = "Minimum number of nodes in the Karpenter system node group."
  type        = number
  default     = 1
}

variable "karpenter_node_max_size" {
  description = "Maximum number of nodes in the Karpenter system node group."
  type        = number
  default     = 3
}

# -----------------------------------------------------------------------------
# Karpenter Helm chart
# -----------------------------------------------------------------------------

variable "karpenter_helm_chart_version" {
  description = "Karpenter Helm chart version to install."
  type        = string
  default     = "1.6.0"
}

variable "install_karpenter_helm" {
  description = "Whether to install Karpenter via Helm from this module (set false if you install it via GitOps)."
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# Cilium
# -----------------------------------------------------------------------------

variable "cilium_egress_masquerade_interfaces" {
  description = "Interface(s) for egress masquerading. eth0 for AL2, ens+ for AL2023. Default eth0 ens+ supports both."
  type        = string
  default     = "eth0 ens+"
}

variable "cilium_cluster_pool_ipv4_cidr" {
  description = "IPv4 CIDR for Cilium cluster-pool IPAM. Must not overlap with VPC. Use CG-NAT space (e.g. 100.64.0.0/16) to avoid conflicts."
  type        = string
  default     = "100.64.0.0/16"
}

variable "cilium_encryption_enabled" {
  description = "Enable transparent encryption (WireGuard) for pod-to-pod traffic between nodes. Helps with compliance (PCI, HIPAA). Slight CPU overhead."
  type        = bool
  default     = true
}

variable "cilium_hubble_enabled" {
  description = "Enable Hubble observability (flow visibility, metrics). Requires Hubble Relay for multi-node clusters."
  type        = bool
  default     = true
}

variable "cilium_prometheus_service_monitor_enabled" {
  description = "Create Prometheus Operator ServiceMonitor resources for Cilium and Hubble metrics. Set true when using Prometheus Operator (kube-prometheus-stack, etc.)."
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Cluster Mesh (multi-cluster)
# -----------------------------------------------------------------------------

variable "cilium_clustermesh_enabled" {
  description = "Enable Cilium Cluster Mesh for multi-cluster pod-to-pod connectivity. Requires cluster.name, cluster.id, and non-overlapping pod CIDRs across clusters."
  type        = bool
  default     = false
}

variable "cilium_cluster_name" {
  description = "Unique cluster name for Cluster Mesh (max 32 chars, lowercase alphanumeric and hyphens). Required when cilium_clustermesh_enabled = true."
  type        = string
  default     = ""

  validation {
    condition     = !var.cilium_clustermesh_enabled || (length(var.cilium_cluster_name) > 0 && length(var.cilium_cluster_name) <= 32)
    error_message = "cilium_cluster_name must be 1-32 characters when cilium_clustermesh_enabled is true."
  }
}

variable "cilium_cluster_id" {
  description = "Unique cluster ID for Cluster Mesh (1-255). Required when cilium_clustermesh_enabled = true. Must be unique across all clusters in the mesh."
  type        = number
  default     = 0

  validation {
    condition     = !var.cilium_clustermesh_enabled || (var.cilium_cluster_id >= 1 && var.cilium_cluster_id <= 255)
    error_message = "cilium_cluster_id must be 1-255 when cilium_clustermesh_enabled is true."
  }
}

variable "cilium_clustermesh_peer_pod_cidrs" {
  description = "List of pod CIDRs from peer clusters. Used to validate no overlap with cilium_cluster_pool_ipv4_cidr. Example: [\"100.65.0.0/16\", \"100.66.0.0/16\"]"
  type        = list(string)
  default     = []
}
