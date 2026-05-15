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

## Key Changes from Upstream

The upstream project targets GKE + Google Cloud. This repository adapts it for AWS:

- **Redis**: cartservice originally depends on in-cluster Redis — replaced with AWS ElastiCache Redis
- **Container registry**: GCR replaced with AWS ECR (immutable tags + Trivy scanning)
- **Ingress**: LoadBalancer Service replaced with AWS ALB Ingress Controller + cert-manager
- **Secret management**: Plaintext env vars replaced with AWS Secrets Manager + External Secrets Operator
- **Observability**: Stackdriver replaced with Prometheus + Grafana

## Repository Structure

```
boutique-aws/
├── .github/
│   └── workflows/
│       ├── infra.yaml          # Terraform plan/apply pipeline
│       └── service.yaml        # Build, test, and deploy pipeline
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
    ├── diagrams/         # Architecture documentation
    └── adr/              # Architecture Decision Records
```

## Getting Started

### Prerequisites

```bash
# 1. Create S3 state backends (one-time setup)
bash terraform/bootstrap/create-state-backend.sh

# 2. Create GitHub Actions IAM roles (one-time setup)
cd terraform/github-actions
terraform init
terraform apply -var="github_repo=<your-github-username>/boutique-aws"
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
ALB_ROLE=$(terraform -chdir=terraform/environments/dev output -raw alb_controller_role_arn)
helm repo add eks https://aws.github.io/eks-charts && helm repo update
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=online-boutique-dev \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$ALB_ROLE

# Install External Secrets Operator
ESO_ROLE=$(terraform -chdir=terraform/environments/dev output -raw external_secrets_role_arn)
helm repo add external-secrets https://charts.external-secrets.io && helm repo update
helm install external-secrets external-secrets/external-secrets \
  -n external-secrets --create-namespace \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$ESO_ROLE
```

### Deploy the Application

```bash
helm upgrade --install online-boutique helm/online-boutique \
  --namespace online-boutique \
  --create-namespace \
  -f helm/online-boutique/values.yaml \
  -f helm/values/values-dev.yaml \
  --set global.registry=<ACCOUNT_ID>.dkr.ecr.ap-northeast-1.amazonaws.com/online-boutique \
  --set global.tag=sha-<short-sha> \
  --set externalSecrets.roleArn=$ESO_ROLE \
  --atomic --wait

# Check status
helm status online-boutique -n online-boutique
kubectl get ingress -n online-boutique

# Rollback
helm rollback online-boutique -n online-boutique
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
