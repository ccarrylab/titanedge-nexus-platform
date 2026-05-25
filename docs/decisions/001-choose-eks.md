# ADR 001: Choose EKS over ECS

## Context
Need a container orchestration platform with rich ecosystem and control plane.

## Decision
Use Amazon EKS. Provides Kubernetes API, broader tooling (Istio, Prometheus), and no vendor lock-in.

## Consequences
Higher operational overhead, but better alignment with platform engineering goals.
