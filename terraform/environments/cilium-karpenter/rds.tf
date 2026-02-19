# -----------------------------------------------------------------------------
# Optional RDS PostgreSQL. Set create_rds_postgres = true to create.
# Uses the rds-postgres module with database subnets from the EKS module.
# -----------------------------------------------------------------------------

module "rds_postgres" {
  source = "../../modules/rds-postgres"

  create = var.create_rds_postgres

  vpc_id                    = module.eks_cilium_karpenter.vpc_id
  allowed_security_group_ids = [module.eks_cilium_karpenter.node_security_group_id]
  db_subnet_group_name      = var.create_rds_postgres ? module.eks_cilium_karpenter.database_subnet_group_name : "unused"

  identifier                 = "${var.name}-${var.environment}-postgres"
  security_group_name_prefix = "${var.name}-${var.environment}-rds-"
  instance_class             = var.rds_instance_class
  allocated_storage          = var.rds_allocated_storage
  engine_version             = var.rds_engine_version
  db_name                    = var.rds_db_name
  username                   = var.rds_username

  tags = merge(var.tags, {
    "Project"     = var.project_tag
    "terraform"   = "true"
    "environment" = var.environment
  })
}
