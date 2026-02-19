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
| **VPC CNI** | Alternative CNI; default AWS pod networking | ✅ (default env) |

---

## Infrastructure as Code

| Tool | Purpose |
|------|---------|
| **Terraform** | EKS, VPC, IAM, node groups, addons; IaC for cluster lifecycle |
| **Helm** | Package management; Cilium, Karpenter, and other workloads |
| **Kustomize** | Overlay-based configuration; GitOps deployments |

---

## GitOps & Deployment

- GitOps deployment patterns (e.g. Flux, Argo CD, or manual Helm/Kustomize)
- Declarative cluster and workload configuration

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

- **RDS** — Database in VPC (rds-postgres module available)
- **External Secrets Operator** — Helm install; integrate with Secrets Manager
- **Kyverno** — Policy enforcement
- **Flux / Argo CD** — Full GitOps automation

---

## Summary

The **cilium-karpenter** environment provides: EKS + Cilium + Karpenter + CoreDNS. The **default** environment provides: EKS + VPC CNI. Both use Terraform and Helm. Additional components (External Secrets, Kyverno, observability agents) can be layered on top via Helm or GitOps.
