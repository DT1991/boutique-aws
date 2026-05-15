# Infrastructure Architecture

## Design Principles

- **Environment isolation**: Each environment has its own VPC (non-overlapping CIDRs), EKS cluster, and ElastiCache instance
- **Least privilege**: Each service's ServiceAccount is bound to a dedicated IAM Role via IRSA
- **Cost gradient**: dev/test use t3 instances with a single NAT Gateway; prod uses m5 instances with per-AZ NAT Gateways

## VPC CIDR Allocation

| Environment | Region | VPC CIDR |
|-------------|--------|----------|
| dev | ap-northeast-1 (Tokyo) | 10.10.0.0/16 |
| test | ap-northeast-1 (Tokyo) | 10.11.0.0/16 |
| perf — primary | ap-northeast-1 (Tokyo) | 10.12.0.0/16 |
| perf — secondary | us-east-1 (Virginia) | 10.14.0.0/16 |
| staging — primary | ap-northeast-1 (Tokyo) | 10.13.0.0/16 |
| staging — secondary | us-east-1 (Virginia) | 10.15.0.0/16 |
| prod — primary | ap-northeast-1 (Tokyo) | 10.0.0.0/16 |
| prod — secondary | us-east-1 (Virginia) | 10.1.0.0/16 |

## Key Design Decisions

### ElastiCache Replacing In-Cluster Redis
See [ADR-001](../adr/ADR-001-elasticache-redis.md)

### ECR Image Management
- All 11 services share a single ECR namespace: `online-boutique/<service>`
- Image tag strategy: `sha-<short-sha>` (immutable tags enforced on the repository)
- Lifecycle policy: untagged images purged after 7 days; up to 50 tagged images retained

### Secret Management
- AWS Secrets Manager holds all credentials (Redis AUTH token, future DB passwords, etc.)
- External Secrets Operator syncs secrets into K8s Secrets within each namespace
- Plaintext secrets must never be committed to Git (enforced by a pre-commit hook)

### Network Security
- Default-deny NetworkPolicy: every service must explicitly declare its allowed ingress and egress
- VPC Flow Logs: 7-day retention in dev; 90-day retention in prod
- S3 and ECR VPC Endpoints reduce NAT Gateway data-transfer costs

## prod Environment Specifications

| Component | Spec | Count |
|-----------|------|-------|
| EKS system nodes | m5.large | 3 (spread across AZs) |
| EKS app nodes | m5.xlarge | 6–50 (auto-scaling) |
| ElastiCache Redis | cache.r6g.large | 3 (Multi-AZ failover) |
| NAT Gateway | — | 3 (one per AZ) |

## Multi-Region Environments (perf / staging / prod)

perf, staging, and prod each deploy two full stacks — Tokyo (primary) and Virginia (secondary) — managed from a single Terraform state file using provider aliases (`aws` for Tokyo, `aws.secondary` for Virginia).

| Component | perf Tokyo | perf Virginia | staging Tokyo | staging Virginia | prod Tokyo | prod Virginia |
|-----------|-----------|---------------|---------------|------------------|------------|---------------|
| VPC CIDR | 10.12.0.0/16 | 10.14.0.0/16 | 10.13.0.0/16 | 10.15.0.0/16 | 10.0.0.0/16 | 10.1.0.0/16 |
| EKS app nodes | 3–20 | 1–10 | 2–10 | 2–8 | 3–50 | 3–50 |
| ElastiCache | r6g.large × 2 | r6g.large × 1 | r6g.large × 2 | r6g.large × 2 | r6g.large × 3 | r6g.large × 3 |

prod secondary is provisioned at the same capacity as primary (active-active). staging secondary runs at reduced capacity (warm standby). perf secondary is minimal (load test target only).

---

# Pipeline Architecture

## Service Pipeline

Triggered on every push to any branch; deploy stages run only on `main`.

```
push
  │
  ├─ Stage 1: Detect changed services (dorny/paths-filter on src/<service>/)
  │
  ├─ Stage 2: Language-specific tests (parallel)
  │   ├── Go:     golangci-lint + go test
  │   ├── Node.js: npm ci + npm test
  │   ├── Python: pytest
  │   ├── .NET:   dotnet test   ← cartservice
  │   └── Java:   gradle test   ← adservice
  │
  ├─ Stage 3: Trivy filesystem scan (fails on CRITICAL/HIGH)
  │
  ├─ Stage 4: Build & push to ECR (main branch only)
  │   └── Trivy image scan + SBOM attestation
  │
  ├─ Stage 5: Deploy → dev (automatic) + smoke test
  │
  ├─ Stage 6: E2E integration tests against dev
  │
  ├─ Stage 7: Deploy → test (automatic)
  │
  ├─ Stage 8: Deploy → perf (automatic)
  │
  ├─ Stage 9: Deploy → staging (requires 1 SRE approval)
  │
  └─ Stage 10: Deploy → prod (requires 2-person approval)
```

## Infra Pipeline

Triggered when any file under `terraform/**` changes.

```
terraform/** change
  │
  ├─ Stage 1: fmt check + tflint + Checkov security scan
  │
  ├─ Stage 2: terraform plan (all 5 environments in parallel)
  │   └── infracost comment on PR
  │
  ├─ Stage 3: Apply → dev (automatic)
  ├─ Stage 4: Apply → test (automatic)
  ├─ Stage 5: Apply → perf (automatic)
  ├─ Stage 6: Apply → staging (requires approval)
  └─ Stage 7: Apply → prod (requires 2-person approval)
```

## Key Design Points

### Build only changed services
`dorny/paths-filter` checks whether `src/<service>/` changed before running tests or builds for that service, avoiding a full 11-service rebuild on every push.

### Parallel multi-language testing
Go, Node.js, Python, .NET, and Java test jobs run concurrently so a slow language runtime does not block the others.

### Immutable image tags
Every image is tagged `sha-<short-sha>`. ECR repositories enforce immutable tags, preventing accidental overwrites of a released image.

### loadgenerator excluded from staging and prod
`values-staging.yaml` and `values-prod.yaml` both set `loadgenerator.enabled: false`, ensuring synthetic load never reaches production users.

### GitHub Actions OIDC authentication
CI jobs authenticate to AWS using OIDC JWT tokens — no long-lived Access Keys are stored. Separate IAM roles are used for build (ECR push only) and deploy (Terraform + EKS full access), each scoped to the specific environment via a `repo:<org>/<repo>:*` trust condition.
