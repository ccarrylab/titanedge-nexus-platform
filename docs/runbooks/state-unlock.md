# Handle Terraform State Lock

When a Terraform run is interrupted, the state may be locked.

1. Run `terraform plan` to see the lock ID:
   ```bash
   cd terraform/environments/dev
   terraform plan
   ```
   Example error: `Error: state locked by ID 123abc`

2. Force unlock **only after** confirming no real operation is in progress:
   ```bash
   terraform force-unlock 123abc
   ```
3. Verify state is unlocked by running `terraform plan` again.
