module "vaults_primary" {
  source = "./modules/regional_vaults"

  name_prefix                    = var.name_prefix
  kms_key_arn                    = aws_kms_key.backup_primary.arn
  workloads                      = toset(keys(local.resource_arns))
  enable_vault_lock              = var.vault_lock_mode != "off"
  vault_lock_changeable_for_days = var.vault_lock_mode == "governance" ? null : var.vault_lock_changeable_for_days
  min_retention_days             = local.min_retention_days
  max_retention_days             = local.max_retention_days
  workload_account_ids           = var.workload_account_ids
  organization_id                = var.organization_id
  partition                      = local.partition
  tags                           = local.common_tags
  resource_type_opt_in           = local.opt_in
}

module "vaults_secondary" {
  source = "./modules/regional_vaults"
  providers = {
    aws = aws.secondary
  }

  name_prefix                    = var.name_prefix
  kms_key_arn                    = aws_kms_replica_key.secondary.arn
  workloads                      = toset(keys(local.resource_arns))
  enable_vault_lock              = var.vault_lock_mode != "off"
  vault_lock_changeable_for_days = var.vault_lock_mode == "governance" ? null : var.vault_lock_changeable_for_days
  min_retention_days             = local.min_retention_days
  max_retention_days             = local.max_retention_days
  workload_account_ids           = var.workload_account_ids
  organization_id                = var.organization_id
  partition                      = local.partition
  tags                           = local.common_tags
  resource_type_opt_in           = local.opt_in
}

module "vaults_tertiary" {
  source = "./modules/regional_vaults"
  providers = {
    aws = aws.tertiary
  }

  name_prefix                    = var.name_prefix
  kms_key_arn                    = aws_kms_replica_key.tertiary.arn
  workloads                      = toset(keys(local.resource_arns))
  enable_vault_lock              = var.vault_lock_mode != "off"
  vault_lock_changeable_for_days = var.vault_lock_mode == "governance" ? null : var.vault_lock_changeable_for_days
  min_retention_days             = local.min_retention_days
  max_retention_days             = local.max_retention_days
  workload_account_ids           = var.workload_account_ids
  organization_id                = var.organization_id
  partition                      = local.partition
  tags                           = local.common_tags
  resource_type_opt_in           = local.opt_in
}
