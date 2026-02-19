# -----------------------------------------------------------------------------
# Karpenter: IAM (controller + node role), SQS queue, EventBridge rules, Pod Identity.
# Optionally install Karpenter Helm chart (disable with install_karpenter_helm = false for GitOps).
# -----------------------------------------------------------------------------

# ECR Public GetAuthorizationToken API is only available in us-east-1 (AWS limitation)
data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.ecr
}

module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 20.0"

  cluster_name = module.eks.cluster_name

  # Node IAM role name must match what you use in Karpenter EC2NodeClass (nodePool)
  node_iam_role_use_name_prefix = false
  node_iam_role_name            = "${local.cluster_name}-karpenter-node"
  create_pod_identity_association = true

  # With Cilium we do not use AWS VPC CNI; do not attach AmazonEKS_CNI_Policy to Karpenter node role
  node_iam_role_attach_cni_policy = false

  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = local.base_tags
}

resource "helm_release" "karpenter" {
  count = var.install_karpenter_helm ? 1 : 0

  depends_on = [helm_release.cilium]

  namespace           = "kube-system"
  name                = "karpenter"
  repository          = "oci://public.ecr.aws/karpenter"
  repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  repository_password = data.aws_ecrpublic_authorization_token.token.password
  chart               = "karpenter"
  version             = var.karpenter_helm_chart_version
  wait                = false

  values = [
    <<-EOT
    nodeSelector:
      karpenter.sh/controller: 'true'
    dnsPolicy: Default
    # Cilium kube-proxy replacement: kubernetes service (172.20.0.1) doesn't route to EKS API.
    # hostNetwork + env vars so controller uses node network (like CoreDNS). METRICS_PORT=8082
    # avoids bind conflict (default 8080). replicas:1 safe when node group has single node.
    hostNetwork: true
    replicas: 1
    controller:
      env:
        - name: KUBERNETES_SERVICE_HOST
          value: "${replace(replace(module.eks.cluster_endpoint, "https://", ""), "http://", "")}"
        - name: KUBERNETES_SERVICE_PORT
          value: "443"
        - name: METRICS_PORT
          value: "8082"
      metrics:
        port: 8082
    settings:
      clusterName: ${module.eks.cluster_name}
      clusterEndpoint: ${module.eks.cluster_endpoint}
      interruptionQueue: ${module.karpenter.queue_name}
    webhook:
      enabled: false
    EOT
  ]
}
