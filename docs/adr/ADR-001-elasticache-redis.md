# ADR-001: Replace In-Cluster Redis with AWS ElastiCache

**Status**: Accepted  
**Date**: 2024-01

## Background

The upstream Online Boutique project runs a Redis instance inside the Kubernetes cluster (`redis-cart` Deployment) to back the cartservice. In a production AWS environment, this approach has several problems:

1. Pod restarts or node evictions cause shopping cart data loss
2. Single point of failure: a Redis pod crash makes all user carts unavailable
3. No persistence or backup
4. Redis becomes a scaling bottleneck as the application grows

## Decision

Replace the in-cluster Redis with **AWS ElastiCache Redis**:

- Provisioned via the Terraform `redis` module
- TLS in transit (`transit_encryption_enabled = true`)
- AUTH token stored in AWS Secrets Manager
- External Secrets Operator syncs the Secrets Manager entry into a K8s Secret
- cartservice reads `REDIS_ADDR` and `REDIS_PASSWORD` from environment variables

## Consequences

- cartservice `REDIS_ADDR` changes from `redis-cart:6379` to the ElastiCache endpoint
- `REDIS_TLS_ENABLED=true` must be set as an additional environment variable
- NetworkPolicy must allow egress on port 6379 to the VPC CIDR
- dev/test use a single `cache.t3.micro` node; prod uses a 3-node `cache.r6g.large` cluster with Multi-AZ failover

## Alternatives Considered

- **Keep in-cluster Redis with a PVC**: Simpler to implement but operationally fragile and not production-grade
- **Replace Redis with DynamoDB**: Would require significant changes to the cartservice .NET code — out of scope for this project
