# Promote from Stage to Production

1. Verify stage environment is healthy:
   ```bash
   kubectl get all -n stage
   ```
2. Review changes in production Terraform:
   ```bash
   cd terraform/environments/prod
   terraform plan -var-file="terraform.tfvars"
   ```
3. Apply the changes (requires approval for prod):
   ```bash
   terraform apply -auto-approve
   ```
4. Sync ArgoCD applications if needed:
   ```bash
   argocd app sync prod-app
   ```
