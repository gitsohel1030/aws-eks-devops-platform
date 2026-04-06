# aws-eks-devops-platform

Production-grade AWS infrastructure for a Kubernetes-based DevOps platform. Provisions a fully automated, GitOps-ready EKS cluster using Terraform — everything from VPC to ArgoCD bootstrap is codified and reproducible with a single `terraform apply`.

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Repository Structure](#repository-structure)
- [Modules](#modules)
- [Prerequisites](#prerequisites)
- [How to Deploy](#how-to-deploy)
- [How to Destroy](#how-to-destroy)
- [Infrastructure Details](#infrastructure-details)
- [Security Design](#security-design)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         AWS Cloud (ap-south-1)                  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    Custom VPC                            │   │
│  │                                                          │   │
│  │  ┌─────────────────┐      ┌─────────────────┐           │   │
│  │  │  Public Subnet  │      │  Public Subnet  │           │   │
│  │  │   (AZ-a)        │      │   (AZ-b)        │           │   │
│  │  │  NAT Gateway    │      │  NAT Gateway    │           │   │
│  │  └────────┬────────┘      └────────┬────────┘           │   │
│  │           │                        │                     │   │
│  │  ┌────────▼────────┐      ┌────────▼────────┐           │   │
│  │  │  Private Subnet │      │  Private Subnet │           │   │
│  │  │   (AZ-a)        │      │   (AZ-b)        │           │   │
│  │  │  EKS Workers    │      │  EKS Workers    │           │   │
│  │  └─────────────────┘      └─────────────────┘           │   │
│  │                                                          │   │
│  │              ┌─────────────────────┐                    │   │
│  │              │   EKS Control Plane │                    │   │
│  │              │   (AWS Managed)     │                    │   │
│  │              └─────────────────────┘                    │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│   S3 (Terraform State)    DynamoDB (State Lock)                  │
│   S3 (Loki Logs)          ECR (Container Images)                 │
│   IAM Roles (IRSA)        ALB (Ingress)                          │
└─────────────────────────────────────────────────────────────────┘
```

---

## Repository Structure

```
aws-eks-devops-platform/
│
├── ecr-repo-tf/                  # ECR repository for container images
│   ├── ecr.tf
│   └── outputs.tf
│
└── terraform/
    ├── envs/
    │   └── prod/                 # Production environment entry point
    │       ├── main.tf           # Module calls
    │       ├── providers.tf      # AWS, Kubernetes, Helm providers
    │       ├── backend.tf        # S3 remote state configuration
    │       ├── variables.tf      # Input variables
    │       ├── outputs.tf        # Output values
    │       ├── storage.tf        # gp3 StorageClass + gp2 demotion
    │       ├── loki.tf           # S3 bucket + IRSA for Loki logging
    │       ├── destroy.sh        # Safe cluster teardown script
    │       └── argocd-ns.json    # ArgoCD namespace bootstrap
    │
    └── modules/
        ├── vpc/                  # VPC, subnets, IGW, NAT, route tables
        ├── eks/                  # EKS cluster, node groups, addons, IRSA
        ├── argocd/               # ArgoCD Helm install + bootstrap
        └── alb-controller/       # AWS Load Balancer Controller
```

---

## Modules

### `modules/vpc`
Provisions the complete network foundation.

| Resource | Details |
|---|---|
| VPC | Custom CIDR, DNS hostnames enabled |
| Public Subnets | 2 AZs, Internet Gateway attached |
| Private Subnets | 2 AZs, NAT Gateway for outbound traffic |
| Route Tables | Separate public/private routing |

---

### `modules/eks`
Provisions the EKS cluster and all Kubernetes infrastructure.

| Resource | Details |
|---|---|
| EKS Cluster | v1.32, private worker nodes |
| Managed Node Groups | t3.medium, AL2023, min 2 / max 3 |
| VPC CNI | Pod networking addon |
| CoreDNS | Cluster DNS addon |
| kube-proxy | Network proxy addon |
| EBS CSI Driver | PersistentVolume provisioning (IRSA) |
| Pod Identity Agent | EKS Pod Identity addon |
| IRSA | OpenID Connect provider for pod-level IAM |

**IRSA Roles:**

| Role | Purpose |
|---|---|
| `{cluster}-ebs-csi-driver` | Allows EBS CSI Driver to provision EBS volumes |
| `{cluster}-loki` | Allows Loki pods to read/write S3 logs bucket |

---

### `modules/argocd`
Installs ArgoCD via Helm and bootstraps the GitOps App of Apps pattern.

| Step | What Happens |
|---|---|
| 1 | Creates `argocd` namespace |
| 2 | Installs ArgoCD via Helm chart |
| 3 | Applies `root-app.yaml` — the App of Apps bootstrap |
| 4 | ArgoCD takes over — syncs all apps from gitops repo |

---

### `modules/alb-controller`
Installs the AWS Load Balancer Controller that provisions ALBs from Kubernetes Ingress resources.

| Resource | Details |
|---|---|
| IAM Role | IRSA-based, least-privilege ELB permissions |
| Helm Release | `aws-load-balancer-controller` chart |

---

### `envs/prod/storage.tf`
Creates and configures Kubernetes StorageClasses at the environment level (not inside the EKS module — avoids circular dependency with the Kubernetes provider).

| Resource | Details |
|---|---|
| `gp3` StorageClass | Default, backed by `ebs.csi.aws.com` provisioner |
| `gp2` annotation patch | Demotes gp2 from default |

---

### `envs/prod/loki.tf`
Provisions AWS resources needed for the Loki log aggregation stack.

| Resource | Details |
|---|---|
| S3 Bucket | `{cluster}-loki-logs`, `force_destroy=true` |
| Public Access Block | All public access blocked |
| Versioning | Enabled |
| Lifecycle Rule | Auto-expire logs after 30 days |
| IAM Policy | Least-privilege S3 read/write for Loki |
| IRSA Role | Maps `logging:loki` ServiceAccount to IAM role |

---

## Prerequisites

| Requirement | Version |
|---|---|
| Terraform | >= 1.3 |
| AWS CLI | >= 2.x |
| kubectl | >= 1.28 |
| Helm | >= 3.x |
| AWS credentials | Configured via IAM role or `aws configure` |

---

## How to Deploy

```bash
# 1. Clone the repository
git clone https://github.com/YOUR_USERNAME/aws-eks-devops-platform.git
cd aws-eks-devops-platform/terraform/envs/prod

# 2. Initialise Terraform (downloads providers and modules)
terraform init

# 3. Review what will be created
terraform plan

# 4. Apply — provisions everything end to end
terraform apply
```

**What `terraform apply` does in order:**

```
VPC + Networking
      ↓
EKS Cluster + Node Groups
      ↓
EKS Addons (VPC CNI, CoreDNS, EBS CSI Driver)
      ↓
IRSA Roles (EBS CSI, Loki)
      ↓
gp3 StorageClass (default)
      ↓
S3 Bucket + IAM for Loki
      ↓
ALB Ingress Controller
      ↓
ArgoCD installed via Helm
      ↓
root-app.yaml applied → ArgoCD bootstraps all apps from gitops repo
```

**After apply, verify:**

```bash
# Nodes are ready
kubectl get nodes

# ArgoCD is running
kubectl get pods -n argocd

# All applications synced
kubectl get applications -n argocd

# StorageClass is correct
kubectl get storageclass
```

---

## How to Destroy

Use the provided destroy script for safe teardown:

```bash
chmod +x destroy.sh
./destroy.sh
```

**What the script does:**

```
1. Disable ArgoCD auto-sync (prevents resources being recreated)
2. Delete ingresses (allows ALBs to clean up from AWS)
3. Wait 30 seconds for ALB deregistration
4. Delete application namespaces (monitoring, logging, prod-app)
5. Wait for namespace termination
6. Run terraform destroy
7. Check for orphaned EBS volumes
```

> ⚠️ Never run `terraform destroy` directly without this script — ArgoCD-managed resources will leave orphaned ALBs and EBS volumes in AWS.

---

## Infrastructure Details

### Remote State

| Resource | Details |
|---|---|
| Backend | S3 bucket |
| State Locking | DynamoDB table |
| Encryption | S3 server-side encryption |

### Provider Authentication

Kubernetes and Helm providers use **exec-based token authentication** — a fresh token is fetched on every Terraform operation. This prevents the 15-minute token expiry issue that occurs with static token-based auth.

```hcl
exec {
  api_version = "client.authentication.k8s.io/v1beta1"
  command     = "aws"
  args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
}
```

---

## Security Design

| Concern | Implementation |
|---|---|
| Worker nodes | Private subnets — not directly internet accessible |
| Pod IAM permissions | IRSA — pod-level IAM roles, not node-level |
| EBS CSI permissions | Scoped to `kube-system:ebs-csi-controller-sa` only |
| Loki S3 permissions | Least-privilege — only required S3 actions |
| ALB Controller | IRSA-scoped to ELB management actions only |
| Cluster access | EKS Access Entries — explicit IAM principal mapping |
| S3 log bucket | All public access blocked |

---

## Related Repositories

| Repository | Purpose |
|---|---|
| [eks-devops-gitops](https://github.com/gitsohel1030/eks-devops-gitops) | GitOps manifests — ArgoCD Applications, Kubernetes configs, Helm values |
| [eks-devops-app](https://github.com/gitsohel1030/eks-devops-app) | Application source — Dockerfile, Jenkinsfile, app code |
