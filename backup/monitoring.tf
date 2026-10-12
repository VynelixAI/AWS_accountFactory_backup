resource "aws_cloudwatch_event_rule" "backup_failed" {
  name        = "${var.name_prefix}-job-failed"
  description = "Notify when an AWS Backup backup, copy, or restore job fails."
  tags        = local.common_tags

  event_pattern = jsonencode({
    source      = ["aws.backup"]
    detail-type = ["Backup Job State Change", "Copy Job State Change", "Restore Job State Change"]
    detail = {
      state = ["FAILED", "ABORTED", "EXPIRED"]
    }
  })
}

resource "aws_cloudwatch_event_target" "backup_failed" {
  rule      = aws_cloudwatch_event_rule.backup_failed.name
  target_id = "BackupAlerts"
  arn       = module.vaults_primary.sns_topic_arn
}

resource "aws_sns_topic_subscription" "alert_email" {
  count = var.alert_email == "" ? 0 : 1

  topic_arn = module.vaults_primary.sns_topic_arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_s3_bucket" "reports" {
  bucket = "${var.name_prefix}-reports-${local.account_id}"
  tags   = local.common_tags
}

resource "aws_s3_bucket_public_access_block" "reports" {
  bucket                  = aws_s3_bucket.reports.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "reports" {
  bucket = aws_s3_bucket.reports.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "reports" {
  bucket = aws_s3_bucket.reports.id
  versioning_configuration {
    status = "Enabled"
  }
}

data "aws_iam_policy_document" "reports" {
  statement {
    sid    = "AllowBackupReports"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:${local.partition}:iam::${local.account_id}:role/aws-service-role/reports.backup.amazonaws.com/AWSServiceRoleForBackupReports"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.reports.arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

resource "aws_s3_bucket_policy" "reports" {
  bucket = aws_s3_bucket.reports.id
  policy = data.aws_iam_policy_document.reports.json
}

resource "aws_backup_report_plan" "jobs" {
  name        = "${var.name_prefix}-job-report"
  description = "Daily report of backup, copy, and restore jobs."
  tags        = local.common_tags

  report_delivery_channel {
    formats        = ["CSV", "JSON"]
    s3_bucket_name = aws_s3_bucket.reports.id
    s3_key_prefix  = "backup-jobs"
  }

  report_setting {
    report_template = "BACKUP_JOB_REPORT"
  }

  depends_on = [aws_s3_bucket_policy.reports]
}
