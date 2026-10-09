# Environment: EKS with default VPC CNI

Uses the **eks-platform** module with `cni_type = "vpc-cni"`. Standard EKS setup with AWS VPC CNI for pod networking. Reference environment — the primary focus is **cilium-karpenter**.

## Files in this environment

| File | Purpose |
|------|---------|
| `main.tf` | Terraform config, providers, eks-platform module |
| `variables.tf` | Input variable definitions (defaults) |
| `terraform.tfvars.example` | **Example values** — copy to `terraform.tfvars` (gitignored); see below |
| `outputs.tf` | Outputs (cluster, kubectl) |

Run `terraform init`, `plan`, and `apply` from this directory.

## Variable files (terraform.tfvars)

**`terraform.tfvars` is not in Git.** Copy the example and edit locally:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Terraform auto-loads `terraform.tfvars` on `plan` / `apply`.

**Different environments:** Use separate `.tfvars` files and pass them explicitly:

```bash
terraform plan -var-file=dev.tfvars
terraform apply -var-file=prod.tfvars
```

Variables not in your tfvars file use the defaults from `variables.tf`.

## Configuration overview

| Component | How it's configured |
|-----------|---------------------|
| **VPC CNI** | AWS EKS addon. Pod networking via VPC secondary IPs. |
| **Kube-proxy** | AWS EKS addon. Service routing (ClusterIP, NodePort, etc.). |
| **CoreDNS** | AWS EKS addon. Standard setup. |

## Variables

Copy **`terraform.tfvars.example`** to **`terraform.tfvars`** (see [Variable files](#variable-files-terraformtfvars)), then edit your local file. Definitions and defaults are in `variables.tf`; the example lists typical values:

- **name**, **environment**: Resource naming (default `jumbo-eks`, `dev`).
- **aws_region**, **aws_profile**: Region and CLI profile (default `eu-central-1`, `null`).
- **vpc_cidr**: VPC CIDR (default `10.0.0.0/16`).
- **kubernetes_version**: EKS version (default `1.34`).
- **node_group_***: Instance types, desired/min/max size, disk size.
- **project_tag**: Tag for resource identification (default `jumbo-eks-demo`).

## Apply flow

1. **Terraform** (creates cluster and node group):

   ```bash
   cp terraform.tfvars.example terraform.tfvars   # first time only
   terraform init
   terraform apply
   ```

2. **Configure kubectl** (use the `configure_kubectl` output):

   ```bash
   aws eks update-kubeconfig --region <region> --name <cluster_name>
   ```
