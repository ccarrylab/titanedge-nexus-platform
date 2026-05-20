# Rotate IAM Credentials

1. Create new access key for the OIDC user:
   ```bash
   aws iam create-access-key --user-name github-oidc-user
   ```
2. Update GitHub secrets:
   - Go to repo **Settings → Secrets and variables → Actions**
   - Update `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` with the new values.
3. Delete the old key:
   ```bash
   aws iam delete-access-key --access-key-id OLD_KEY --user-name github-oidc-user
   ```
