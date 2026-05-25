# ADR 003: Single Region Deployment

## Context
We need a deployment region strategy. Options: single region vs multi-region active‑active.

## Decision
Deploy only in `us-east-1` (single region). Reasons:
- **Cost** – multi‑region doubles infrastructure costs.
- **Complexity** – multi‑region requires global load balancing, database replication, and failover automation.
- **Latency** – user base is primarily in North America.

## Consequences
- **Lower resilience** – region failure would cause downtime.
- **Mitigations** – RDS Multi‑AZ, EKS control plane in multiple AZs, S3 cross‑region replication for critical data.
- **Future** – adopt active‑passive with Route53 failover if requirements change.
