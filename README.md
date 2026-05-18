# Online Boutique — Production DevOps Infrastructure

AWS-based production deployment of [GoogleCloudPlatform/microservices-demo](https://github.com/GoogleCloudPlatform/microservices-demo) (Online Boutique).

The upstream project is Google's demo e-commerce platform consisting of 11 microservices communicating over gRPC with a polyglot tech stack. This repository provides:

- **Task 1** — Terraform IaC (VPC / EKS / ElastiCache / ECR / S3)
- **Task 2** — Helm chart for all 11 services with per-environment values
- **Task 3** — GitHub Actions CI/CD (infra pipeline + service pipeline)
- **Task 4** — Architecture documentation and design decisions

## Services

| Service | Language | Responsibility |
|---------|----------|----------------|
| frontend | Go | HTTP server, renders UI, aggregates downstream gRPC calls |
| cartservice | C# (.NET) | Shopping cart, backed by Redis |
| productcatalogservice | Go | Product listing, reads from JSON file |
| currencyservice | Node.js | Currency conversion, highest QPS service |
| paymentservice | Node.js | Simulated credit card charge |
| shippingservice | Go | Shipping cost estimate and simulated dispatch |
| emailservice | Python | Sends order confirmation emails (simulated) |
| checkoutservice | Go | Order flow orchestrator, calls 6 downstream services |
| recommendationservice | Python | Product recommendations |
| adservice | Java | Ad serving |
| loadgenerator | Python/Locust | Synthetic traffic generator (non-production only) |

## AWS Adaptations

The upstream project targets GKE. This repository deploys it on AWS with the following stack:

- **Cart storage**: AWS ElastiCache Redis — managed, Multi-AZ failover, TLS + AUTH via Secrets Manager
- **Container registry**: AWS ECR — immutable tags, Trivy image scanning, lifecycle policies
- **Ingress**: AWS ALB Ingress Controller — HTTPS termination, ACM certificate, access logs to S3
- **Observability**: Prometheus + Grafana — ServiceMonitor and PrometheusRule templates included (`monitoring.enabled: true` to activate)
- **Node.js services**: Patched Dockerfiles under `docker/` pin Node.js 20 in both build and runtime stages, avoiding a native module ABI incompatibility introduced by Alpine 3.23 shipping Node.js 24

## Repository Structure

```
boutique-aws/
├── .github/
│   └── workflows/
│       ├── infra.yaml          # Terraform plan/apply pipeline
│       └── service.yaml        # Build, test, and deploy pipeline
├── docker/
│   ├── currencyservice/        # Patched Dockerfile (Node.js 20, fixes ABI incompatibility)
│   └── paymentservice/         # Patched Dockerfile (Node.js 20, fixes ABI incompatibility)
├── terraform/
│   ├── bootstrap/
│   │   └── create-state-backend.sh   # Create S3 state buckets (run once)
│   ├── github-actions/               # GitHub Actions OIDC IAM roles (run once)
│   ├── modules/
│   │   ├── vpc/          # VPC, subnets, NAT GW, VPC endpoints, Flow Logs
│   │   ├── eks/          # EKS cluster, node groups, IRSA, managed add-ons
│   │   ├── redis/        # ElastiCache Redis (replaces in-cluster Redis)
│   │   ├── ecr/          # ECR repositories (11 services)
│   │   └── s3/           # ALB access log bucket
│   └── environments/
│       ├── dev/          # Single AZ, t3 instances, single NAT
│       ├── test/         # Single AZ, t3 instances
│       ├── perf/         # Multi-region (Tokyo + Virginia), larger instances, load testing
│       ├── staging/      # Multi-AZ, production-like spec
│       └── prod/         # Multi-AZ, full HA, m5 instances
├── helm/
│   ├── online-boutique/      # Umbrella Helm chart (all 11 services)
│   │   ├── Chart.yaml
│   │   ├── values.yaml       # Default values (all environments inherit)
│   │   └── templates/
│   │       ├── services/     # Deployment + Service + HPA + PDB per service
│   │       ├── ingress/      # ALB Ingress
│   │       ├── rbac/         # ClusterSecretStore (External Secrets Operator)
│   │       ├── monitoring/   # ServiceMonitor + PrometheusRule
│   │       └── network-policy/
│   └── values/
│       ├── values-dev.yaml
│       ├── values-test.yaml
│       ├── values-perf.yaml
│       ├── values-staging.yaml
│       └── values-prod.yaml
└── docs/
    └── diagrams/         # Application, infrastructure, and pipeline architecture diagrams
```

## Getting Started

### Prerequisites

```bash
# 1. Create S3 state backends (one-time setup)
bash terraform/bootstrap/create-state-backend.sh

# 2. Create GitHub Actions IAM roles (one-time setup)
cd terraform/github-actions
terraform init
terraform apply -var="github_repo=DT1991/boutique-aws"
terraform output github_secrets_setup   # copy these values to GitHub Secrets
```

### Deploy Infrastructure

```bash
cd terraform/environments/dev
terraform init
terraform apply
```

### Install Prerequisites on the Cluster

```bash
# Update kubeconfig
aws eks update-kubeconfig --name online-boutique-dev --region ap-northeast-1

# Install AWS Load Balancer Controller
helm repo add eks https://aws.github.io/eks-charts && helm repo update
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=online-boutique-dev \
  --set region=ap-northeast-1 \
  --set vpcId=$(terraform -chdir=terraform/environments/dev output -raw vpc_id)
```

### Deploy the Application

The service pipeline handles deployment automatically on push to `main`. For manual deployment:

```bash
# 1. Get Redis connection string (TLS + auth required for ElastiCache)
REDIS_HOST=$(aws elasticache describe-replication-groups \
  --replication-group-id online-boutique-dev-redis \
  --query 'ReplicationGroups[0].NodeGroups[0].PrimaryEndpoint.Address' \
  --output text \
  --region ap-northeast-1)

REDIS_PASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id online-boutique-dev/redis/auth-token \
  --query 'SecretString' \
  --output text \
  --region ap-northeast-1 | jq -r '.auth_token')

REDIS_ADDR="${REDIS_HOST}:6379,password=${REDIS_PASSWORD},ssl=true,abortConnect=false"

# 2. Write Redis addr to a temp values file (commas in the value break --set)
cat > /tmp/redis-values.yaml << EOF
services:
  cartservice:
    redis:
      addr: "${REDIS_ADDR}"
EOF

# 3. Deploy
helm upgrade --install online-boutique helm/online-boutique \
  --namespace online-boutique \
  --create-namespace \
  -f helm/online-boutique/values.yaml \
  -f helm/values/values-dev.yaml \
  -f /tmp/redis-values.yaml \
  --set global.registry=<ACCOUNT_ID>.dkr.ecr.ap-northeast-1.amazonaws.com/online-boutique \
  --set global.tag=sha-<short-sha> \
  --timeout 10m

# Check status
helm status online-boutique -n online-boutique
kubectl get pods -n online-boutique
kubectl get ingress -n online-boutique

# Rollback
helm rollback online-boutique -n online-boutique
```

## DNS & TLS Setup

Automate DNS record management (Route 53) and TLS certificate issuance (Let's Encrypt) using `external-dns` and `cert-manager`.

> **Prerequisites**: a real domain registered and hosted in Route 53 (e.g. `boutique-team.com`), EKS cluster running with AWS Load Balancer Controller installed.

### Install external-dns

The IAM policy and IRSA role are provisioned by Terraform — no manual IAM steps needed.

```bash
helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/ && helm repo update

EXTERNAL_DNS_ROLE_ARN=$(terraform -chdir=terraform/environments/dev output -raw external_dns_role_arn)
CLUSTER_NAME=online-boutique-dev

helm upgrade --install external-dns external-dns/external-dns \
  --namespace kube-system \
  --set provider=aws \
  --set aws.region=ap-northeast-1 \
  --set txtOwnerId=${CLUSTER_NAME} \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=${EXTERNAL_DNS_ROLE_ARN} \
  --set policy=upsert-only

# Verify
kubectl get pods -n kube-system -l app.kubernetes.io/name=external-dns
kubectl logs -n kube-system -l app.kubernetes.io/name=external-dns --tail=30
```

### Install cert-manager

```bash
helm repo add jetstack https://charts.jetstack.io && helm repo update

helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true

# Create ClusterIssuer (use letsencrypt-staging for non-prod to avoid rate limits)
kubectl apply -f - <<'EOF'
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: <YOUR_EMAIL>
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - http01:
          ingress:
            class: alb
EOF

# Verify
kubectl get clusterissuer
```

### Enable per environment

In `helm/values/values-<env>.yaml`:

```yaml
certManager:
  enabled: true
  issuer: letsencrypt-prod   # or letsencrypt-staging for non-prod
```

cert-manager will perform the ACME HTTP-01 challenge via the ALB and store the certificate as a Kubernetes Secret. external-dns will create the Route 53 A record automatically.

```bash
# Verify end-to-end
kubectl get certificate -n online-boutique
dig dev.online-boutique.boutique-team.com
curl -I https://dev.online-boutique.boutique-team.com
```

## Environment Specifications

| | dev | test | perf | staging | prod |
|--|-----|------|------|---------|------|
| Regions | 1 | 1 | 2 (Tokyo + Virginia) | 2 (Tokyo + Virginia) | 2 (Tokyo + Virginia) |
| NAT Gateways | 1 | 1 | 3+3 | 3+3 | 3+3 |
| EKS node type | t3.medium | t3.medium | m5.large | m5.large | m5.xlarge |
| App nodes (primary) | 1-5 | 1-5 | 3-20 | 2-10 | 3-50 |
| App nodes (secondary) | — | — | 1-10 | 2-8 | 3-50 |
| Redis nodes (per region) | 1 | 1 | 2 / 1 | 2 / 2 | 3 / 3 |
| loadgenerator | yes | yes | yes | no | no |
