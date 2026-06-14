#!/bin/bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Prerequisites that are NOT yet provisioned by this repo's Terraform:
#
#   1. IAM role + IRSA trust policy for the AWS Load Balancer Controller's
#      service account (commonly named AmazonEKSLoadBalancerControllerRole,
#      built from the AWS-published AWSLoadBalancerControllerIAMPolicy).
#   2. IAM role "KarpenterControllerRole-${AWS_ACCOUNT_ID}" referenced in
#      karpenter-values.yaml, with an IRSA trust policy scoped to the
#      "karpenter" service account in the "karpenter" namespace.
#
# Until those roles exist, the aws-load-balancer-controller and karpenter
# pods will start but their AWS API calls will fail (no credentials). See
# FINDINGS.md for tracking.
# ---------------------------------------------------------------------------

CLUSTER_NAME="${CLUSTER_NAME:-titanedge-nexus-dev}"
AWS_REGION="${AWS_REGION:-us-east-1}"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text)}"

CLUSTER_ENDPOINT="$(aws eks describe-cluster \
  --name "${CLUSTER_NAME}" \
  --region "${AWS_REGION}" \
  --query 'cluster.endpoint' \
  --output text)"

VPC_ID="$(aws eks describe-cluster \
  --name "${CLUSTER_NAME}" \
  --region "${AWS_REGION}" \
  --query 'cluster.resourcesVpcConfig.vpcId' \
  --output text)"

echo "Cluster: ${CLUSTER_NAME} (${CLUSTER_ENDPOINT}, vpc ${VPC_ID})"

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# ---------------------------------------------------------------------------
# kube-prometheus-stack (Prometheus + Grafana + Alertmanager)
# Grafana is bundled as a subchart, so it isn't installed separately.
# Picks up the existing grafana-datasources / prometheus-config ConfigMaps
# in the monitoring namespace.
# ---------------------------------------------------------------------------
helm install prometheus prometheus-community/kube-prometheus-stack \
  --version 86.2.3 \
  --namespace monitoring \
  --create-namespace

# ---------------------------------------------------------------------------
# AWS Load Balancer Controller
# Requires the IRSA role described above (serviceAccount.create=false +
# an existing "aws-load-balancer-controller" service account annotated
# with the role ARN). Until that role exists, this installs the controller
# but it will not be able to provision ALBs/NLBs.
# ---------------------------------------------------------------------------
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --version 1.14.0 \
  --namespace kube-system \
  --set clusterName="${CLUSTER_NAME}" \
  --set region="${AWS_REGION}" \
  --set vpcId="${VPC_ID}"

# ---------------------------------------------------------------------------
# Karpenter
# Requires "KarpenterControllerRole-${AWS_ACCOUNT_ID}" (IRSA role, see above).
# Modern Karpenter charts (1.x) discover the cluster endpoint automatically;
# only clusterName/interruptionQueue need to be set explicitly.
# ---------------------------------------------------------------------------
helm install karpenter oci://public.ecr.aws/karpenter/karpenter \
  --version 1.12.1 \
  --namespace karpenter \
  --create-namespace \
  -f karpenter-values.yaml \
  --set settings.clusterName="${CLUSTER_NAME}" \
  --set settings.interruptionQueue="${CLUSTER_NAME}" \
  --set-string "serviceAccount.annotations.eks\.amazonaws\.com/role-arn=arn:aws:iam::${AWS_ACCOUNT_ID}:role/KarpenterControllerRole-${AWS_ACCOUNT_ID}"
