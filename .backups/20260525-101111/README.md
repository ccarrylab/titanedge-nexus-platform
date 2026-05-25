# Titanedge Nexus Platform

[![CI/CD](https://github.com/ccarrylab/titanedge-nexus-platform/actions/workflows/terraform.yml/badge.svg)](https://github.com/ccarrylab/titanedge-nexus-platform/actions/workflows/terraform.yml)
[![Security](https://github.com/ccarrylab/titanedge-nexus-platform/actions/workflows/security.yml/badge.svg)](https://github.com/ccarrylab/titanedge-nexus-platform/actions/workflows/security.yml)
[![Terraform Version](https://img.shields.io/badge/terraform-%3E%3D%201.5.0-blue)](https://terraform.io)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)


Production-style AWS infrastructure platform built with Terraform, Kubernetes, and GitOps workflows.

## Platform Features

- Multi-environment AWS infrastructure
- Amazon EKS platform
- Terraform modular architecture
- Kubernetes workload orchestration
- GitHub Actions CI/CD
- Centralized observability
- Cloud-native security controls
- Infrastructure automation

## Technology Stack

- Terraform
- AWS
- Kubernetes
- EKS
- Prometheus
- Grafana
- GitHub Actions

## Infrastructure Components

- VPC
- EKS
- RDS PostgreSQL
- CloudWatch
- IAM
- Observability stack

## Status

Actively evolving platform engineering environment focused on deployment automation and operational reliability.

---

## CI/CD Platform Engineering

The platform uses enterprise-style GitHub Actions workflows with:

- Terraform validation
- Security scanning
- Drift detection
- Kubernetes manifest validation
- FinOps policy checks
- Artifact management
- Multi-stage deployment gates
- OIDC-based AWS authentication
- Manual production approvals

### Deployment Strategy

dev -> stage -> production

### Security Tooling

- tfsec
- Checkov
- TFLint
- pre-commit hooks

### Operational Features

- Infrastructure drift detection
- GitOps workflows
- Cost optimization validation
- Deployment promotion controls


<img width="1536" height="1024" alt="TitanEdge Nexus platform architecture diagram" src="https://github.com/user-attachments/assets/92c84377-adc5-43c4-b571-2dbc335db085" />

