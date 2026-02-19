# rds-postgres module

Optional RDS PostgreSQL instance for EKS workloads. Deploy in database subnets (same VPC as cluster), with a security group allowing connections from EKS nodes.

---

## PostgreSQL on AWS: RDS overview

**Amazon RDS (Relational Database Service)** is a managed database service. Instead of running PostgreSQL yourself on EC2, AWS provisions, patches, backs up, and monitors the database. You choose the engine (PostgreSQL, MySQL, MariaDB, etc.), instance size, and storage; AWS handles the rest.

**Why RDS for PostgreSQL?**

- **Managed operations**: Automated backups, patching, failover (Multi-AZ), scaling
- **PostgreSQL compatibility**: Standard PostgreSQL protocol (port 5432), extensions, tooling
- **Security**: Encryption at rest (KMS), encryption in transit (TLS), VPC isolation

**Placement and networking:**

- RDS instances run in **private subnets** (no direct internet access)
- A **DB subnet group** tells RDS which subnets it can use; AWS requires at least 2 AZs for high availability
- A **security group** controls who can connect (typically only your application tier, e.g. EKS nodes)
- `publicly_accessible = false` keeps the instance private inside the VPC

---

## How this module reflects AWS concepts in Terraform

| AWS concept | Terraform resource / config | Purpose |
|-------------|-----------------------------|---------|
| **DB subnet group** | `db_subnet_group_name` (input) | RDS must be placed in subnets that belong to a DB subnet group. The caller (e.g. EKS/VPC module) creates the subnets and group; this module uses the group name. |
| **Private placement** | `publicly_accessible = false` | Instance is only reachable from within the VPC. |
| **Network access** | `aws_security_group.rds` | Ingress on port 5432 from allowed SGs (e.g. EKS node SG). Pods egress via nodes, so allowing the node SG is enough. |
| **Encryption at rest** | `storage_encrypted = true` | Data on disk is encrypted with AWS KMS. |
| **Automated backups** | `backup_retention_period = 7` | Point-in-time recovery for 7 days. |
| **Master credentials** | `random_password.rds` + `username` / `password` | Master user and a randomly generated password; no secrets in code. |
| **Instance sizing** | `instance_class`, `allocated_storage` | Controls compute and storage (e.g. `db.t3.micro` for dev/test). |

---

## Terraform resources in this module

```
main.tf
├── random_password.rds     → 24-char password for the master user
├── aws_security_group.rds  → Allow 5432 from allowed_security_group_ids
└── aws_db_instance.postgres → The RDS PostgreSQL instance
```

**`aws_db_instance.postgres`** is the core resource. It wires together:

- **Engine**: `engine = "postgres"`, `engine_version` (e.g. `"16"`)
- **Placement**: `db_subnet_group_name` (which subnets), `vpc_security_group_ids` (who can connect)
- **Credentials**: `username`, `password` (from `random_password`)
- **Storage**: `allocated_storage`, `storage_encrypted`
- **Backup**: `backup_retention_period`

**`aws_security_group.rds`** restricts access to port 5432 from the given security groups. For EKS, you pass the **node security group** so that pods (which egress through nodes) can reach RDS.

---

## Usage

```hcl
module "rds_postgres" {
  source = "../../modules/rds-postgres"

  create = var.create_rds_postgres

  vpc_id                    = module.eks.vpc_id
  allowed_security_group_ids = [module.eks.node_security_group_id]
  db_subnet_group_name      = module.eks.database_subnet_group_name

  identifier                 = "${var.name}-${var.environment}-postgres"
  security_group_name_prefix = "${var.name}-${var.environment}-rds-"
  instance_class             = var.rds_instance_class
  allocated_storage          = var.rds_allocated_storage
  engine_version             = var.rds_engine_version
  db_name                    = var.rds_db_name
  username                   = var.rds_username

  tags = var.tags
}
```

---

## Inputs

| Name | Description | Default |
|------|-------------|---------|
| create | Whether to create RDS | `false` |
| vpc_id | VPC ID | required |
| allowed_security_group_ids | SGs allowed to connect (e.g. EKS node SG) | required |
| db_subnet_group_name | DB subnet group name | required |
| identifier | RDS instance identifier | required |
| security_group_name_prefix | SG name prefix | required |
| instance_class | Instance class | `db.t3.micro` |
| allocated_storage | Storage GB | `20` |
| engine_version | PostgreSQL version | `16` |
| db_name | Default database name | `app` |
| username | Master username | `postgres` |
| tags | Resource tags | `{}` |

---

## Outputs

| Name | Description |
|------|-------------|
| endpoint | RDS endpoint hostname |
| port | RDS port |
| password | Master password (sensitive) |
| connection_string | Connection string template |

---

## Requirements

- `hashicorp/aws` >= 5.0
- `hashicorp/random` >= 3.0
