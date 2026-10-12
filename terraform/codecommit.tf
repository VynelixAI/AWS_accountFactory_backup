resource "aws_codecommit_repository" "account_request" {
  count = var.create_codecommit_repo ? 1 : 0

  repository_name = var.account_request_repo_name
  description     = "Account request Terraform. PR to main → pipeline creates/closes accounts via Organizations."

  tags = local.common_tags
}

resource "aws_codecommit_approval_rule_template" "require_one_approval" {
  name        = "${var.project_name}-require-one-approval"
  description = "Require at least one approval before merging to main"

  content = jsonencode({
    Version               = "2018-11-08"
    DestinationReferences = ["refs/heads/${var.default_branch}"]
    Statements = [{
      Type                    = "Approvers"
      NumberOfApprovalsNeeded = 1
      ApprovalPoolMembers     = ["*"]
    }]
  })
}

resource "aws_codecommit_approval_rule_template_association" "main" {
  count = var.create_codecommit_repo ? 1 : 0

  approval_rule_template_name = aws_codecommit_approval_rule_template.require_one_approval.name
  repository_name             = aws_codecommit_repository.account_request[0].repository_name
}
