#!/bin/bash
set -euo pipefail
 
REGION="ap-south-1"
 
echo "Fetching Terraform outputs..."
VPC_ID=$(terraform output -raw vpc_id)
CLUSTER_NAME=$(terraform output -raw cluster_name)
 
echo "============================================"
echo "[1] Disable ArgoCD auto-sync"
echo "============================================"
kubectl patch applications.argoproj.io --all -n argocd \
  --type merge -p '{"spec":{"syncPolicy":null}}' || true
 
echo "============================================"
echo "[2] Delete GitOps applications"
echo "============================================"
kubectl delete applications.argoproj.io --all -n argocd --ignore-not-found
 
echo "============================================"
echo "[3] Delete workload namespace"
echo "============================================"
kubectl delete ns prod-app --ignore-not-found
 
echo "============================================"
echo "[4] Delete Ingress (triggers ALB cleanup)"
echo "============================================"
kubectl delete ingress -A --all --ignore-not-found
 
echo "============================================"
echo "[5] Wait for ALB cleanup (CRITICAL)"
echo "============================================"
 
for i in {1..15}; do
  LB_COUNT=$(aws elbv2 describe-load-balancers \
    --region $REGION \
    --query "length(LoadBalancers[?VpcId=='$VPC_ID'])" \
    --output text)
 
  TG_COUNT=$(aws elbv2 describe-target-groups \
    --region $REGION \
    --query "length(TargetGroups[?VpcId=='$VPC_ID'])" \
    --output text)
 
  echo "Attempt $i → LBs: $LB_COUNT, TGs: $TG_COUNT"
 
  if [[ "$LB_COUNT" == "0" && "$TG_COUNT" == "0" ]]; then
    echo "All ALBs and Target Groups deleted ✔"
    break
  fi
 
  sleep 20
done
 
echo "============================================"
echo "[6] Uninstall ALB controller"
echo "============================================"
helm uninstall aws-load-balancer-controller -n kube-system || true
 
echo "============================================"
echo "[7] Terraform destroy"
echo "============================================"
terraform destroy -auto-approve
 
echo "============================================"
echo "✅ CLEAN DESTROY COMPLETE"
echo "============================================"
 