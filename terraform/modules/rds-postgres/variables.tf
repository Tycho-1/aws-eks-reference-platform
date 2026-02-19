# -----------------------------------------------------------------------------
# rds-postgres module - Optional RDS PostgreSQL for EKS workloads
# -----------------------------------------------------------------------------

variable "create" {
  description = "Whether to create the RDS PostgreSQL instance."
  type        = bool
  default     = false
}

variable "vpc_id" {
  description = "VPC ID where RDS will be deployed."
  type        = string
}

variable "allowed_security_group_ids" {
  description = "List of security group IDs allowed to connect to RDS on port 5432 (e.g. EKS node SG)."
  type        = list(string)
}

variable "db_subnet_group_name" {
  description = "Name of the DB subnet group (subnets must be in the VPC)."
  type        = string
}

variable "identifier" {
  description = "RDS instance identifier."
  type        = string
}

variable "instance_class" {
  description = "RDS instance class (e.g. db.t3.micro for testing)."
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Allocated storage in GB."
  type        = number
  default     = 20
}

variable "engine_version" {
  description = "PostgreSQL engine version."
  type        = string
  default     = "16"
}

variable "db_name" {
  description = "Name of the default database."
  type        = string
  default     = "app"
}

variable "username" {
  description = "Master username for RDS."
  type        = string
  default     = "postgres"
}

variable "security_group_name_prefix" {
  description = "Prefix for the RDS security group name."
  type        = string
}

variable "tags" {
  description = "Tags to apply to RDS and security group."
  type        = map(string)
  default     = {}
}
