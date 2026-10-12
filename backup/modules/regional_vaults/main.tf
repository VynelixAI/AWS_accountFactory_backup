resource "aws_backup_region_settings" "this" {
  resource_type_opt_in_preference = var.resource_type_opt_in
}

resource "aws_sns_topic" "alerts" {
  name = "${var.name_prefix}-backup-alerts"
  tags = var.tags
}

data "aws_iam_policy_document" "alerts" {
  statement {
    sid    = "AllowBackupPublish"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
    actions   = ["SNS:Publish"]
    resources = [aws_sns_topic.alerts.arn]
  }

  statement {
    sid    = "AllowEventBridgePublish"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
    actions   = ["SNS:Publish"]
    resources = [aws_sns_topic.alerts.arn]
  }
}

resource "aws_sns_topic_policy" "alerts" {
  arn    = aws_sns_topic.alerts.arn
  policy = data.aws_iam_policy_document.alerts.json
}

resource "aws_backup_vault" "this" {
  for_each = var.workloads

  name        = "${var.name_prefix}-${each.key}"
  kms_key_arn = var.kms_key_arn
  tags        = merge(var.tags, { Workload = each.key })
}

resource "aws_backup_vault_lock_configuration" "this" {
  for_each = var.enable_vault_lock ? aws_backup_vault.this : {}

  backup_vault_name   = each.value.name
  changeable_for_days = var.vault_lock_changeable_for_days
  min_retention_days  = var.min_retention_days
  max_retention_days  = var.max_retention_days
}

resource "aws_backup_vault_notifications" "this" {
  for_each = aws_backup_vault.this

  backup_vault_name = each.value.name
  sns_topic_arn     = aws_sns_topic.alerts.arn
  backup_vault_events = [
    "BACKUP_JOB_FAILED",
    "BACKUP_JOB_EXPIRED",
    "COPY_JOB_FAILED",
    "RESTORE_JOB_FAILED",
  ]

  depends_on = [aws_sns_topic_policy.alerts]
}

data "aws_iam_policy_document" "vault" {
  for_each = length(var.workload_account_ids) > 0 || var.organization_id != "" ? aws_backup_vault.this : {}

  dynamic "statement" {
    for_each = length(var.workload_account_ids) > 0 ? [1] : []
    content {
      sid    = "AllowListedAccountsToCopyIn"
      effect = "Allow"
      principals {
        type        = "AWS"
        identifiers = [for account_id in var.workload_account_ids : "arn:${var.partition}:iam::${account_id}:root"]
      }
      actions = [
        "backup:CopyIntoBackupVault",
        "backup:DescribeBackupVault",
        "backup:ListRecoveryPointsByBackupVault",
      ]
      resources = [each.value.arn]
    }
  }

  dynamic "statement" {
    for_each = var.organization_id != "" ? [1] : []
    content {
      sid    = "AllowOrganizationToCopyIn"
      effect = "Allow"
      principals {
        type        = "AWS"
        identifiers = ["*"]
      }
      actions = [
        "backup:CopyIntoBackupVault",
        "backup:DescribeBackupVault",
        "backup:ListRecoveryPointsByBackupVault",
      ]
      resources = [each.value.arn]
      condition {
        test     = "StringEquals"
        variable = "aws:PrincipalOrgID"
        values   = [var.organization_id]
      }
    }
  }
}

resource "aws_backup_vault_policy" "this" {
  for_each = data.aws_iam_policy_document.vault

  backup_vault_name = aws_backup_vault.this[each.key].name
  policy            = each.value.json
}
