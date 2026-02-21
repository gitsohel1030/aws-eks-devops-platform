#!/bin/bash
set -e

### CONFIG ###
VPC_ID=$(terraform output -raw vpc_id)
CLUSTER_NAME=$(terraform output -raw cluster_name)
REGION="ap-south-1"

echo "VPC: $VPC_ID"
echo "Cluster: $CLUSTER_NAME"
echo "Region: $REGION"

echo "============================================"
echo "[1] Delete all Ingresses + LoadBalancer Services"
echo "============================================"
kubectl delete ingress -A --all || true
kubectl delete svc -A --all || true

echo "============================================"
echo "[2] Uninstall ALB controller (stops reconciliation)"
echo "============================================"
helm uninstall aws-load-balancer-controller -n kube-system || true

echo "============================================"
echo "[3] Force delete ALBs & Target Groups in VPC"
echo "============================================"

# Delete ALBs
for LB_ARN in $(aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?VpcId=='$VPC_ID'].LoadBalancerArn" \
  --output text); do
  
  echo "Deleting LB: $LB_ARN"
  
  # Delete listeners
  for L in $(aws elbv2 describe-listeners --load-balancer-arn "$LB_ARN" --query 'Listeners[].ListenerArn' --output text); do
    aws elbv2 delete-listener --listener-arn "$L" || true
  done
  
  aws elbv2 delete-load-balancer --load-balancer-arn "$LB_ARN" || true
done

# Delete Target Groups
for TG_ARN in $(aws elbv2 describe-target-groups \
  --query "TargetGroups[?VpcId=='$VPC_ID'].TargetGroupArn" \
  --output text); do
  echo "Deleting TG: $TG_ARN"
  aws elbv2 delete-target-group --target-group-arn "$TG_ARN" || true
done

# echo "============================================"
# echo "[4] Wait for ENIs to disappear"
# echo "============================================"

# while true; do
#   ENI_COUNT=$(aws ec2 describe-network-interfaces \
#     --filters "Name=vpc-id,Values=$VPC_ID" \
#     --query "length(NetworkInterfaces)" \
#     --output text)
    
#   if [[ "$ENI_COUNT" == "0" ]]; then
#     echo "All ENIs deleted!"
#     break
#   fi
  
#   echo "ENIs still present ($ENI_COUNT)... waiting 10s"
#   sleep 10
# done

# echo "============================================"
# echo "[5] Destroy EKS module"
# echo "============================================"
# terraform destroy -target=module.eks -auto-approve

# echo "============================================"
# echo "[6] Destroy remaining VPC resources"
# echo "============================================"
terraform destroy -auto-approve