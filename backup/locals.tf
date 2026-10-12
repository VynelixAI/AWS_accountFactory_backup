check "cold_storage_retention" {
  assert {
    condition     = var.standard_retention_days >= var.standard_cold_storage_after_days + 90
    error_message = "AWS Backup requires retention to be at least 90 days longer than the cold-storage transition."
  }
}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition

  common_tags = merge(
    {
      Project   = "aws-backup"
      ManagedBy = "Terraform"
    },
    var.tags
  )

  min_retention_days = min(
    var.dynamodb_pitr_retention_days,
    var.standard_retention_days,
    var.s3_retention_days
  )
  max_retention_days = max(var.standard_retention_days, var.s3_retention_days)

  resource_arns = {
    ec2      = ["arn:${local.partition}:ec2:*:*:instance/*", "arn:${local.partition}:ec2:*:*:volume/*"]
    db2      = ["arn:${local.partition}:ec2:*:*:instance/*", "arn:${local.partition}:ec2:*:*:volume/*"]
    aurora   = ["arn:${local.partition}:rds:*:*:cluster:*"]
    s3       = ["arn:${local.partition}:s3:::*"]
    dynamodb = ["arn:${local.partition}:dynamodb:*:*:table/*"]
  }

  opt_in = {
    "Aurora"                 = true
    "CloudFormation"         = true
    "DocumentDB"             = true
    "DynamoDB"               = true
    "EBS"                    = true
    "EC2"                    = true
    "EFS"                    = true
    "FSx"                    = true
    "Neptune"                = true
    "RDS"                    = true
    "Redshift"               = true
    "S3"                     = true
    "SAP HANA on Amazon EC2" = true
    "Storage Gateway"        = true
    "Timestream"             = true
    "VirtualMachine"         = true
  }
}
