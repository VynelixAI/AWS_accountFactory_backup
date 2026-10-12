locals {
  copy_destinations = {
    for workload in keys(local.resource_arns) : workload => [
      module.vaults_secondary.vault_arns[workload],
      module.vaults_tertiary.vault_arns[workload],
    ]
  }
}

resource "aws_backup_plan" "ec2" {
  name = "${var.name_prefix}-ec2-daily"
  tags = local.common_tags

  rule {
    rule_name         = "daily"
    target_vault_name = module.vaults_primary.vault_names["ec2"]
    schedule          = var.schedule_expression
    start_window      = 60
    completion_window = 480

    lifecycle {
      cold_storage_after                        = var.standard_cold_storage_after_days
      delete_after                              = var.standard_retention_days
      opt_in_to_archive_for_supported_resources = true
    }

    dynamic "copy_action" {
      for_each = local.copy_destinations["ec2"]
      content {
        destination_vault_arn = copy_action.value
        lifecycle {
          cold_storage_after                        = var.standard_cold_storage_after_days
          delete_after                              = var.standard_retention_days
          opt_in_to_archive_for_supported_resources = true
        }
      }
    }

    recovery_point_tags = merge(local.common_tags, { Workload = "ec2" })
  }

  advanced_backup_setting {
    resource_type = "EC2"
    backup_options = {
      WindowsVSS = "enabled"
    }
  }
}

resource "aws_backup_plan" "db2" {
  name = "${var.name_prefix}-db2-daily"
  tags = local.common_tags

  rule {
    rule_name         = "daily"
    target_vault_name = module.vaults_primary.vault_names["db2"]
    schedule          = var.schedule_expression
    start_window      = 60
    completion_window = 480

    lifecycle {
      cold_storage_after                        = var.standard_cold_storage_after_days
      delete_after                              = var.standard_retention_days
      opt_in_to_archive_for_supported_resources = true
    }

    dynamic "copy_action" {
      for_each = local.copy_destinations["db2"]
      content {
        destination_vault_arn = copy_action.value
        lifecycle {
          cold_storage_after                        = var.standard_cold_storage_after_days
          delete_after                              = var.standard_retention_days
          opt_in_to_archive_for_supported_resources = true
        }
      }
    }

    recovery_point_tags = merge(local.common_tags, { Workload = "db2" })
  }
}

resource "aws_backup_plan" "aurora" {
  name = "${var.name_prefix}-aurora-daily"
  tags = local.common_tags

  rule {
    rule_name         = "daily"
    target_vault_name = module.vaults_primary.vault_names["aurora"]
    schedule          = var.schedule_expression
    start_window      = 60
    completion_window = 480

    lifecycle {
      cold_storage_after                        = var.standard_cold_storage_after_days
      delete_after                              = var.standard_retention_days
      opt_in_to_archive_for_supported_resources = true
    }

    dynamic "copy_action" {
      for_each = local.copy_destinations["aurora"]
      content {
        destination_vault_arn = copy_action.value
        lifecycle {
          cold_storage_after                        = var.standard_cold_storage_after_days
          delete_after                              = var.standard_retention_days
          opt_in_to_archive_for_supported_resources = true
        }
      }
    }

    recovery_point_tags = merge(local.common_tags, { Workload = "aurora" })
  }
}

resource "aws_backup_plan" "s3" {
  name = "${var.name_prefix}-s3-daily"
  tags = local.common_tags

  rule {
    rule_name         = "daily-incremental"
    target_vault_name = module.vaults_primary.vault_names["s3"]
    schedule          = var.schedule_expression
    start_window      = 60
    completion_window = 720

    lifecycle {
      delete_after = var.s3_retention_days
    }

    dynamic "copy_action" {
      for_each = local.copy_destinations["s3"]
      content {
        destination_vault_arn = copy_action.value
        lifecycle {
          delete_after = var.s3_retention_days
        }
      }
    }

    recovery_point_tags = merge(local.common_tags, { Workload = "s3" })
  }
}

resource "aws_backup_plan" "dynamodb" {
  name = "${var.name_prefix}-dynamodb"
  tags = local.common_tags

  rule {
    rule_name                = "continuous"
    target_vault_name        = module.vaults_primary.vault_names["dynamodb"]
    schedule                 = var.schedule_expression
    enable_continuous_backup = true
    start_window             = 60
    completion_window        = 180

    lifecycle {
      delete_after = var.dynamodb_pitr_retention_days
    }

    recovery_point_tags = merge(local.common_tags, { Workload = "dynamodb", BackupType = "pitr" })
  }

  rule {
    rule_name         = "daily"
    target_vault_name = module.vaults_primary.vault_names["dynamodb"]
    schedule          = var.schedule_expression
    start_window      = 60
    completion_window = 480

    lifecycle {
      cold_storage_after                        = var.standard_cold_storage_after_days
      delete_after                              = var.standard_retention_days
      opt_in_to_archive_for_supported_resources = true
    }

    dynamic "copy_action" {
      for_each = local.copy_destinations["dynamodb"]
      content {
        destination_vault_arn = copy_action.value
        lifecycle {
          cold_storage_after                        = var.standard_cold_storage_after_days
          delete_after                              = var.standard_retention_days
          opt_in_to_archive_for_supported_resources = true
        }
      }
    }

    recovery_point_tags = merge(local.common_tags, { Workload = "dynamodb", BackupType = "daily" })
  }
}

resource "aws_backup_selection" "workload" {
  for_each = local.resource_arns

  name         = "${each.key}-by-tag"
  plan_id      = local.plan_ids[each.key]
  iam_role_arn = aws_iam_role.backup.arn
  resources    = concat(each.value, lookup(var.additional_resource_arns, each.key, []))

  selection_tag {
    type  = "STRINGEQUALS"
    key   = var.backup_tag_key
    value = each.key
  }
}

locals {
  plan_ids = {
    ec2      = aws_backup_plan.ec2.id
    db2      = aws_backup_plan.db2.id
    aurora   = aws_backup_plan.aurora.id
    s3       = aws_backup_plan.s3.id
    dynamodb = aws_backup_plan.dynamodb.id
  }
}
