data "aws_iam_policy_document" "backup_kms" {
  statement {
    sid    = "RootAdministration"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:${local.partition}:iam::${local.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowBackupService"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
    actions = [
      "kms:CreateGrant",
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:GenerateDataKey",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "kms:CallerAccount"
      values   = [local.account_id]
    }
  }
}

resource "aws_kms_key" "backup_primary" {
  description             = "Multi-region CMK for AWS Backup vaults"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  multi_region            = true
  policy                  = data.aws_iam_policy_document.backup_kms.json
  tags                    = local.common_tags
}

resource "aws_kms_alias" "backup_primary" {
  name          = "alias/${var.name_prefix}-vault"
  target_key_id = aws_kms_key.backup_primary.key_id
}

resource "aws_kms_replica_key" "secondary" {
  provider = aws.secondary

  description             = "Replica CMK for AWS Backup vaults in ${var.secondary_region}"
  primary_key_arn         = aws_kms_key.backup_primary.arn
  deletion_window_in_days = 30
  policy                  = data.aws_iam_policy_document.backup_kms.json
  tags                    = local.common_tags
}

resource "aws_kms_alias" "secondary" {
  provider = aws.secondary

  name          = "alias/${var.name_prefix}-vault"
  target_key_id = aws_kms_replica_key.secondary.key_id
}

resource "aws_kms_replica_key" "tertiary" {
  provider = aws.tertiary

  description             = "Replica CMK for AWS Backup vaults in ${var.tertiary_region}"
  primary_key_arn         = aws_kms_key.backup_primary.arn
  deletion_window_in_days = 30
  policy                  = data.aws_iam_policy_document.backup_kms.json
  tags                    = local.common_tags
}

resource "aws_kms_alias" "tertiary" {
  provider = aws.tertiary

  name          = "alias/${var.name_prefix}-vault"
  target_key_id = aws_kms_replica_key.tertiary.key_id
}
