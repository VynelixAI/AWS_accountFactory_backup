# Runbook — personal account, no Control Tower

## 1. Organization

If you do not have an Organization yet:

```bash
aws organizations create-organization
aws organizations list-roots --query 'Roots[0].Id' --output text
```

Use that Root ID as `parent_ou_id`.

## 2. Deploy factory

```bash
bash scripts/package_lambda.sh
cd terraform
cp terraform.tfvars.example terraform.tfvars
# set parent_ou_id
terraform init && terraform apply
```

## 3. Launch CREATE

1. Service Catalog → Products → Account Request → Launch.
2. **ServiceToken** = `terraform output -raw lambda_function_arn`
3. AccountName, AccountEmail (unique), OrganizationalUnit, Operation=CREATE.
4. Open PullRequestUrl → Approve → Merge.
5. Watch pipeline `account-factory-account-request-pipeline` until Apply succeeds.
6. Check: `aws organizations list-accounts`

## 4. Launch DELETE

Same product, Operation=DELETE, same AccountName → approve PR → pipeline closes account (`close_on_deletion = true`).

## 5. Common issues

| Issue | Fix |
|-------|-----|
| Not in organization | Create organization from management account |
| Email already used | Use a new unique email |
| Lambda AccessDenied on Organizations | Must run in management account |
| Pipeline apply fails | CodeBuild logs; check Organizations quotas |
| Service Catalog cannot launch | Add your user to portfolio Access |

## 6. Costs

Each member account can incur charges. Close test accounts when done. Permanent deletion of a closed account takes time per AWS policy.
