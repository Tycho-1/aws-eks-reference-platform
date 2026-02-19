variable "aws_region" {
  description = "AWS region for the EKS cluster and VPC."
  type        = string
  default     = "eu-central-1"
}

variable "aws_profile" {
  description = "AWS CLI profile name (from ~/.aws/credentials). Leave null to use default profile or env vars."
  type        = string
  default     = null
}

variable "name" {
  description = "Name prefix for resources."
  type        = string
  default     = "jumbo-eks"
}

variable "environment" {
  description = "Environment (e.g. dev, staging, prod)."
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version."
  type        = string
  default     = "1.34"
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

variable "install_karpenter_helm" {
  description = "Whether to install Karpenter via Helm from this example (set false if using GitOps)."
  type        = bool
  default     = true
}

variable "karpenter_helm_chart_version" {
  description = "Karpenter Helm chart version."
  type        = string
  default     = "1.6.0"
}

variable "karpenter_workload_capacity_type" {
  description = "Capacity type for Karpenter-provisioned workload nodes: 'spot' (cheapest, can be interrupted), 'on_demand' (stable, prod-like), or 'spot_and_on_demand' (both)."
  type        = string
  default     = "spot"

  validation {
    condition     = contains(["spot", "on_demand", "spot_and_on_demand"], var.karpenter_workload_capacity_type)
    error_message = "karpenter_workload_capacity_type must be spot, on_demand, or spot_and_on_demand."
  }
}

variable "karpenter_create_default_nodepool" {
  description = "Create a default NodePool and EC2NodeClass so Karpenter can provision workload nodes. Set false if you manage these via GitOps."
  type        = bool
  default     = true
}

variable "karpenter_nodepool_limit_cpu" {
  description = "Max total allocatable CPU (cores) across Karpenter workload nodes. Prevents runaway provisioning. Default 100 for small testing (~10-15 nodes); use 1000+ for prod."
  type        = string
  default     = "100"
}

variable "karpenter_nodepool_limit_memory" {
  description = "Max total allocatable memory across Karpenter workload nodes (BinarySI: Gi, Mi). Default 400Gi for small testing; use 2000Gi+ for prod."
  type        = string
  default     = "400Gi"
}

variable "cilium_egress_masquerade_interfaces" {
  description = "Interface(s) for Cilium egress masquerading. Use eth0 for AL2 (default), ens+ or en+ for AL2023."
  type        = string
  default     = "eth0"
}

variable "cilium_cluster_pool_ipv4_cidr" {
  description = "IPv4 CIDR for Cilium cluster-pool IPAM. Must not overlap with VPC. Default 100.64.0.0/16 (CG-NAT space)."
  type        = string
  default     = "100.64.0.0/16"
}

variable "cilium_encryption_enabled" {
  description = "Enable WireGuard encryption for pod-to-pod traffic between nodes. Default true for compliance. Set false for performance-sensitive workloads."
  type        = bool
  default     = true
}

variable "cilium_hubble_enabled" {
  description = "Enable Hubble observability (flow visibility, metrics). Set false to disable."
  type        = bool
  default     = true
}

variable "cilium_prometheus_service_monitor_enabled" {
  description = "Create Prometheus Operator ServiceMonitor for Cilium/Hubble metrics. Set true when using kube-prometheus-stack or similar."
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Cluster Mesh (multi-cluster)
# -----------------------------------------------------------------------------

variable "cilium_clustermesh_enabled" {
  description = "Enable Cilium Cluster Mesh for multi-cluster pod-to-pod connectivity."
  type        = bool
  default     = false
}

variable "cilium_cluster_name" {
  description = "Unique cluster name for Cluster Mesh (max 32 chars, lowercase alphanumeric and hyphens). Required when clustermesh enabled."
  type        = string
  default     = ""
}

variable "cilium_cluster_id" {
  description = "Unique cluster ID for Cluster Mesh (1-255). Required when clustermesh enabled."
  type        = number
  default     = 0
}

variable "cilium_clustermesh_peer_pod_cidrs" {
  description = "Pod CIDRs from peer clusters for overlap validation. Example: [\"100.65.0.0/16\"]"
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------------------------
# RDS PostgreSQL (optional)
# -----------------------------------------------------------------------------

variable "create_rds_postgres" {
  description = "Create an RDS PostgreSQL instance. Default false — create cluster first, then set true and apply to add RDS."
  type        = bool
  default     = false
}

variable "rds_instance_class" {
  description = "RDS instance class (e.g. db.t3.micro for testing)."
  type        = string
  default     = "db.t3.micro"
}

variable "rds_allocated_storage" {
  description = "RDS allocated storage in GB."
  type        = number
  default     = 20
}

variable "rds_engine_version" {
  description = "PostgreSQL engine version."
  type        = string
  default     = "16"
}

variable "rds_db_name" {
  description = "Name of the default database."
  type        = string
  default     = "app"
}

variable "rds_username" {
  description = "Master username for RDS."
  type        = string
  default     = "postgres"
}

variable "project_tag" {
  description = "Value for the 'Project' tag on all resources. Use this to find and identify resources (e.g. in Tag Editor) after terraform destroy to catch any leftovers."
  type        = string
  default     = "jumbo-eks-demo"
}

variable "tags" {
  description = "Additional tags (merged with Project = project_tag)."
  type        = map(string)
  default     = {}
}
