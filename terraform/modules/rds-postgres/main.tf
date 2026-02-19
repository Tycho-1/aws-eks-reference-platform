# -----------------------------------------------------------------------------
# RDS PostgreSQL - private instance in database subnets
# -----------------------------------------------------------------------------

resource "random_password" "rds" {
  count   = var.create ? 1 : 0
  length  = 24
  special = false
}

resource "aws_security_group" "rds" {
  count       = var.create ? 1 : 0
  name_prefix = var.security_group_name_prefix
  description = "Allow PostgreSQL from allowed security groups"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = var.allowed_security_group_ids
    description     = "PostgreSQL from allowed SGs"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_instance" "postgres" {
  count = var.create ? 1 : 0

  identifier     = var.identifier
  engine         = "postgres"
  engine_version = var.engine_version

  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage

  db_name  = var.db_name
  username = var.username
  password = random_password.rds[0].result

  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = [aws_security_group.rds[0].id]
  publicly_accessible    = false

  backup_retention_period = 7
  storage_encrypted       = true

  tags = var.tags
}
