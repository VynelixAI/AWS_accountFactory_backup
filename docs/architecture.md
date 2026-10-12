# Architecture (no Control Tower)

```mermaid
sequenceDiagram
    participant User
    participant SC as Service Catalog
    participant CFN as CloudFormation
    participant L as Lambda
    participant Org as Organizations
    participant CC as CodeCommit
    participant Human
    participant Pipe as CodePipeline
    participant TF as Terraform Apply

    User->>SC: Launch Account Request
    SC->>CFN: Create stack
    CFN->>L: Custom resource
    L->>Org: Create OU if missing
    L->>L: Generate accounts/name.tf
    L->>CC: Branch + commit + PR
    L-->>User: PullRequestUrl
    Human->>CC: Approve + merge main
    CC->>Pipe: Source change
    Pipe->>TF: terraform apply
    TF->>Org: CreateAccount / CloseAccount
```

## What gets generated

```hcl
resource "aws_organizations_account" "sandbox_01" {
  name              = "sandbox-01"
  email             = "you+sandbox-01@example.com"
  parent_id         = "ou-xxxx-yyyy"
  role_name         = "OrganizationAccountAccessRole"
  close_on_deletion = true
  tags              = { ... }
}
```

No Control Tower, no AFT, no Service Catalog Account Factory product from CT.
