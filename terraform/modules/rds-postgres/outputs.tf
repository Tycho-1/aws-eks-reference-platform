# -----------------------------------------------------------------------------
# RDS PostgreSQL outputs (null when create = false)
# -----------------------------------------------------------------------------

output "endpoint" {
  description = "RDS endpoint hostname."
  value       = var.create ? aws_db_instance.postgres[0].endpoint : null
}

output "port" {
  description = "RDS port."
  value       = var.create ? aws_db_instance.postgres[0].port : null
}

output "password" {
  description = "RDS master password (randomly generated)."
  value       = var.create ? random_password.rds[0].result : null
  sensitive   = true
}

output "connection_string" {
  description = "Connection string template. Replace <PASSWORD> with terraform output -raw rds_password."
  value       = var.create ? "postgresql://${var.username}:<PASSWORD>@${aws_db_instance.postgres[0].endpoint}:5432/${var.db_name}" : null
}
