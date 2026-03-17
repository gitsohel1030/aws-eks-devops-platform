#!/bin/bash
set -euo pipefail

### CONFIG ###
REGION="ap-south-1"

echo "Fetching Terraform outputs..."
VPC_ID=$(terraform output -raw vpc_id)
CLUSTER_NAME=$(terraform output -raw cluster_name)

echo "VPC: $VPC_ID"
echo "Cluster: $CLUSTER_NAME"
echo "Region: $REGION"

echo "============================================"
echo "[0] Disable ArgoCD sync (prevent re-creation)"
echo "============================================"
kubectl patch applications.argoproj.io --all -n argocd \
  --type merge -p '{"spec":{"syncPolicy":null}}' || true

echo "============================================"
echo "[1] Delete all apps (GitOps cleanup)"
echo "============================================"
kubectl delete applications.argoproj.io --all -n argocd || true

echo "============================================"
echo "[2] Delete namespaces (workloads)"
echo "============================================"
kubectl delete ns prod-app --ignore-not-found=true || true

echo "============================================"
echo "[3] Delete ingress + LB services"
echo "============================================"
kubectl delete ingress -A --all || true
kubectl delete svc -A --all || true

echo "============================================"
echo "[4] Remove finalizers (force cleanup if stuck)"
echo "============================================"
for i in $(kubectl get ingress -A -o name); do
  kubectl patch $i -p '{"metadata":{"finalizers":[]}}' --type=merge || true
done

echo "============================================"
echo "[5] Uninstall ALB controller"
echo "============================================"
helm uninstall aws-load-balancer-controller -n kube-system || true

echo "============================================"
echo "[6] Delete Load Balancers"
echo "============================================"
for LB_ARN in $(aws elbv2 describe-load-balancers \
  --region $REGION \
  --query "LoadBalancers[?VpcId=='$VPC_ID'].LoadBalancerArn" \
  --output text); do

  echo "Deleting LB: $LB_ARN"

  for L in $(aws elbv2 describe-listeners \
    --region $REGION \
    --load-balancer-arn "$LB_ARN" \
    --query 'Listeners[].ListenerArn' \
    --output text); do
    aws elbv2 delete-listener --region $REGION --listener-arn "$L" || true
  done

  aws elbv2 delete-load-balancer \
    --region $REGION \
    --load-balancer-arn "$LB_ARN" || true
done

echo "============================================"
echo "[7] Delete Target Groups"
echo "============================================"
for TG_ARN in $(aws elbv2 describe-target-groups \
  --region $REGION \
  --query "TargetGroups[?VpcId=='$VPC_ID'].TargetGroupArn" \
  --output text); do

  echo "Deleting TG: $TG_ARN"
  aws elbv2 delete-target-group \
    --region $REGION \
    --target-group-arn "$TG_ARN" || true
done

echo "============================================"
echo "[8] Wait for ENIs cleanup (CRITICAL)"
echo "============================================"
while true; do
  ENI_COUNT=$(aws ec2 describe-network-interfaces \
    --region $REGION \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query "length(NetworkInterfaces)" \
    --output text)

  if [[ "$ENI_COUNT" == "0" ]]; then
    echo "All ENIs deleted!"
    break
  fi

  echo "ENIs still present ($ENI_COUNT)... waiting 15s"
  sleep 15
done

echo "============================================"
echo "[9] Terraform Destroy"
echo "============================================"
terraform destroy -auto-approve

echo "============================================"
echo "✅ FULL CLEANUP COMPLETED"
echo "============================================"
 