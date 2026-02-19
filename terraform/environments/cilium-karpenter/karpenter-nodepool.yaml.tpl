apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: default
spec:
  # AL2 is deprecated on EKS 1.33+; use AL2023 (see https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions-standard.html#kubernetes-1-33)
  amiFamily: AL2023
  amiSelectorTerms:
    - alias: al2023@latest
  role: ${node_iam_role_name}
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: ${cluster_name}
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: ${cluster_name}
---
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  template:
    spec:
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: default
      requirements:
        - key: karpenter.sh/capacity-type
          operator: In
          values:
${capacity_type_values_yaml}
        - key: kubernetes.io/arch
          operator: In
          values:
            - amd64
        - key: karpenter.k8s.aws/instance-generation
          operator: Gt
          values:
            - "2"
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values:
            - c
            - m
            - r
      # Cilium adds this taint during bootstrap; DaemonSet removes it when agent is ready.
      # startupTaints: pods don't need to tolerate—Karpenter knows it's temporary.
      startupTaints:
        - key: node.cilium.io/agent-not-ready
          value: "true"
          effect: NoExecute
      expireAfter: 720h
  limits:
    cpu: "${nodepool_limit_cpu}"
    memory: "${nodepool_limit_memory}"
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    consolidateAfter: 1m
