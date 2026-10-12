# Account Factory (No Control Tower)

Self-service AWS account creation for a **personal / standalone AWS Organizations** account — **without Control Tower**.

## Same flow, simpler backend

```
Service Catalog
      → CloudFormation custom resource
      → Lambda
           1. Create OU if missing
           2. Generate Terraform (aws_organizations_account)
           3. Branch + commit + open PR on account-request repo
      → You approve the PR
      → Merge to main
      → CodePipeline runs terraform apply
      → New AWS account is created under the OU
```

Deletion: Lambda opens a PR that removes the account `.tf` file; after merge, Terraform closes/removes the resource (account is closed via Organizations, not hard-deleted immediately).

---

## Step-by-step (do this in order)

### Step 0 – Prerequisites

1. AWS account that is the **management account** of an AWS Organization (or create an Organization: Organizations → Create organization).
2. AWS CLI configured (`aws configure`) with admin access in that account.
3. Terraform >= 1.5 installed.
4. Python 3.12 (for packaging Lambda if you change code).
5. Note your **Root ID**:  
   ```bash
   aws organizations list-roots --query 'Roots[0].Id' --output text
   ```
   Example: `r-xxxx`

### Step 1 – Unzip and package Lambda

```bash
cd account-factory-no-ct
bash scripts/package_lambda.sh
```

### Step 2 – Configure Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
aws_region   = "us-east-1"
project_name = "account-factory"
environment  = "test"
parent_ou_id = "r-xxxx"   # from Step 0
```

### Step 3 – Deploy the factory infrastructure

```bash
terraform init
terraform plan
terraform apply
```

Save the outputs (Lambda ARN, portfolio ID, repo clone URL).

### Step 4 – Allow yourself to launch the product

Console: **Service Catalog → Portfolios → Account Factory Portfolio → Access → Add user/role**

Or set in `terraform.tfvars` and re-apply:

```hcl
launch_role_principal_arns = ["arn:aws:iam::YOUR_ACCOUNT_ID:user/YOUR_USER"]
```

### Step 5 – Request a new account (CREATE)

1. **Service Catalog → Products → Account Request → Launch product**
2. Parameters:
   - **ServiceToken** = Lambda ARN from Terraform output `lambda_function_arn`
   - **AccountName** = e.g. `sandbox-01`
   - **AccountEmail** = unique email you control
   - **OrganizationalUnit** = e.g. `Sandbox` (created if missing)
   - **Operation** = `CREATE`
3. After the stack succeeds, open **PullRequestUrl**.
4. **CodeCommit → Pull requests → Approve → Merge** into `main`.
5. Pipeline runs `terraform apply` and creates the account under that OU.

### Step 6 – Close an account request (DELETE)

Launch the same product with **Operation = DELETE** and the same **AccountName**.  
Approve/merge the PR; Terraform will attempt to remove the account resource (Organizations closes the account; full deletion is delayed by AWS).

### Step 7 – Verify

```bash
aws organizations list-accounts
aws organizations list-organizational-units-for-parent --parent-id r-xxxx
```

---

## Repo layout

```
account-factory-no-ct/
├── README.md
├── terraform/           # Factory infra (Lambda, SC, CodeCommit, pipeline)
├── lambda/              # PR + OU + TF generator
├── cloudformation/      # Service Catalog product template
├── docs/
└── scripts/
```

## Important (personal account)

- Account emails must be **unique** and reachable.
- Creating accounts has **cost** and **quota** limits.
- For flow testing only, you can stop after PR merge and inspect generated `.tf` without keeping many accounts.
- This does **not** use Control Tower, AFT, or Account Factory products from CT.

## Docs

- [Architecture](docs/architecture.md)
- [Runbook](docs/runbook.md)
