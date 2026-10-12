data "aws_iam_policy_document" "backup_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "backup" {
  name               = "${var.name_prefix}-service"
  assume_role_policy = data.aws_iam_policy_document.backup_assume.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "backup" {
  for_each = toset([
    "arn:${local.partition}:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup",
    "arn:${local.partition}:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores",
    "arn:${local.partition}:iam::aws:policy/AWSBackupServiceRolePolicyForS3Backup",
    "arn:${local.partition}:iam::aws:policy/AWSBackupServiceRolePolicyForS3Restore",
  ])

  role       = aws_iam_role.backup.name
  policy_arn = each.value
}

data "aws_iam_policy_document" "db2_ssm" {
  statement {
    sid    = "RunDb2QuiesceDocuments"
    effect = "Allow"
    actions = [
      "ssm:SendCommand",
      "ssm:GetCommandInvocation",
      "ssm:CancelCommand",
    ]
    resources = [
      aws_ssm_document.db2_quiesce.arn,
      aws_ssm_document.db2_resume.arn,
      "arn:${local.partition}:ec2:${var.primary_region}:${local.account_id}:instance/*",
    ]
  }

  statement {
    sid       = "ReadDb2CommandResults"
    effect    = "Allow"
    actions   = ["ssm:ListCommands", "ssm:ListCommandInvocations"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "db2_ssm" {
  name   = "${var.name_prefix}-db2-ssm"
  role   = aws_iam_role.backup.id
  policy = data.aws_iam_policy_document.db2_ssm.json
}
