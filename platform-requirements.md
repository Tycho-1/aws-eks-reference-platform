# Platform Requirements

Base requirements for the EKS reference platform, aligned with container platform engineering practices. This document defines the tech stack and components each environment should support or consider.

---

## Core Platform Components

| Component | Purpose | Status in this repo |
|-----------|---------|---------------------|
| **EKS cluster** | Managed Kubernetes control plane; production-ready with upgrades, migrations, troubleshooting support | ✅ |
| **CoreDNS** | Cluster DNS; EKS addon with EKS-specific workarounds where needed (e.g. Cilium kube-proxy replacement) | ✅ |
| **Cilium** | CNI and kube-proxy replacement; networking, network policies, observability (Hubble) | ✅ (cilium-karpenter env) |
| **Karpenter** | Node autoscaling; provisions EC2 nodes based on pod demand | ✅ (cilium-karpenter env) |
| **VPC CNI** | Alternative CNI; default AWS pod networking | ✅ (default env; reference only, not tested) |
| **Flux GitOps** | Declarative cluster and workload deployment from Git | ✅ optional (`cilium-karpenter` env; `enable_flux_gitops`) |
| **RDS PostgreSQL** | Optional database in VPC database subnets | ✅ optional (`rds-postgres` module; `create_rds_postgres`) |

---

## Infrastructure as Code

| Tool | Purpose |
|------|---------|
| **Terraform** | EKS, VPC, IAM, node groups, addons; IaC for cluster lifecycle |
| **Helm** | Package management; Cilium, Karpenter, and other workloads |
| **Kustomize** | Overlay-based configuration; GitOps deployments |

---

## GitOps & Deployment

| Component | Status |
|-----------|--------|
| **Flux** | ✅ Bootstrap via Terraform in `cilium-karpenter` env (optional flag) |
| **Argo CD** | Not implemented |
| **Helm / Kustomize** | ✅ Used for Cilium, Karpenter; Flux fleet repo is external |

---

## Security

| Component | Purpose |
|-----------|---------|
| **RBAC** | Role-based access control; cluster and namespace permissions |
| **External Secrets Operator** | Sync secrets from AWS Secrets Manager / Vault into Kubernetes |
| **Kyverno** | Policy engine; enforce security and governance policies |
| **Container security** | Image scanning, runtime policies, network policies (Cilium) |

---

## AWS Services

| Service | Usage |
|---------|-------|
| **EC2** | Worker nodes (managed node groups, Karpenter-provisioned) |
| **VPC** | Networking; public/private subnets, NAT, security groups |
| **IAM** | Cluster roles, node roles, IRSA (pod identity) |
| **ALB / NLB** | Load balancing; Ingress, LoadBalancer services |
| **Secrets Manager** | Secrets storage; integration with External Secrets |

---

## Observability

| Tool | Purpose |
|-----|---------|
| **Datadog** | Primary; metrics, logs, APM |
| **Grafana** | Dashboards, visualization |
| **Prometheus** | Metrics collection; often used with Grafana |
| **Hubble** | Cilium flow visibility; network observability |

---

## Optional / Future Additions

- **External Secrets Operator** — Helm install; integrate with Secrets Manager (RDS creds out of TF state)
- **Kyverno** — Policy enforcement
- **Argo CD** — Alternative GitOps controller
- **ALB Ingress Controller** — L2 cluster entry
- **VPC endpoints** — Reduce NAT dependency for private clusters
- **Observability stack** — Prometheus/Grafana or Datadog

---

## Summary

The **cilium-karpenter** environment provides: EKS + Cilium (Helm) + Karpenter + CoreDNS, with optional Flux GitOps and optional RDS PostgreSQL. The **default** environment provides: EKS + VPC CNI (reference only). Both wrap the community `terraform-aws-modules/eks` module. Additional components (External Secrets, Kyverno, observability agents) can be layered on top via Helm or GitOps.
