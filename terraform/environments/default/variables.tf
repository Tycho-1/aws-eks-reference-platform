variable "aws_region" {
  description = "AWS region for the EKS cluster and VPC."
  type        = string
  default     = "eu-central-1"
}

variable "aws_profile" {
  description = "AWS CLI profile name (from ~/.aws/credentials). Leave null to use default profile or env vars (AWS_ACCESS_KEY_ID, etc.)."
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

variable "enable_default_node_group" {
  description = "Create a default managed node group."
  type        = bool
  default     = true
}

variable "node_group_instance_types" {
  description = "EC2 instance types for the default node group."
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
