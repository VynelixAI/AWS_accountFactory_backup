variable "name_prefix" {
  type        = string
  default     = "aws-backup"
  description = "Prefix for vaults, plans, and KMS aliases."
}

variable "primary_region" {
  type        = string
  default     = "us-east-1"
  description = "Region where workloads and the primary backup vaults run."
}

variable "secondary_region" {
  type        = string
  default     = "us-east-2"
  description = "First cross-region copy destination."
}

variable "tertiary_region" {
  type        = string
  default     = "us-west-2"
  description = "Second cross-region copy destination."
}

variable "backup_tag_key" {
  type        = string
  default     = "BackupWorkload"
  description = "Tag key used to select resources. Values: ec2, db2, aurora, s3, dynamodb."
}

variable "schedule_expression" {
  type        = string
  default     = "cron(0 5 ? * * *)"
  description = "Daily backup schedule in AWS cron format. Default is 05:00 UTC."
}

variable "standard_cold_storage_after_days" {
  type        = number
  default     = 7
  description = "Move EC2, DB2, Aurora, and DynamoDB daily recovery points to cold storage after this many days. The diagram example is 7."
}

variable "standard_retention_days" {
  type        = number
  default     = 97
  description = "Delete EC2, DB2, Aurora, and DynamoDB daily recovery points after this many days. The diagram example is 35, which AWS rejects because cold storage must be kept at least 90 days. 97 is 7 + 90."
}

variable "s3_retention_days" {
  type        = number
  default     = 365
  description = "Delete S3 recovery points after this many days. S3 backups cannot transition to cold storage; AWS ignores that lifecycle setting."
}

variable "dynamodb_pitr_retention_days" {
  type        = number
  default     = 35
  description = "Retention for the DynamoDB continuous (point-in-time) backup. AWS allows at most 35 days."

  validation {
    condition     = var.dynamodb_pitr_retention_days >= 1 && var.dynamodb_pitr_retention_days <= 35
    error_message = "DynamoDB continuous backup retention must be from 1 to 35 days."
  }
}

variable "vault_lock_mode" {
  type        = string
  default     = "governance"
  description = "governance keeps Vault Lock removable during the change window. compliance is irreversible after that window. off creates vaults without a lock."

  validation {
    condition     = contains(["governance", "compliance", "off"], var.vault_lock_mode)
    error_message = "vault_lock_mode must be governance, compliance, or off."
  }
}

variable "vault_lock_changeable_for_days" {
  type        = number
  default     = 3
  description = "Days a governance or compliance lock can still be changed. Minimum is 3. Ignored when vault_lock_mode is off."
}

variable "workload_account_ids" {
  type        = list(string)
  default     = []
  description = "Member accounts allowed to copy recovery points into these vaults. Leave empty when backups run in this account."
}

variable "organization_id" {
  type        = string
  default     = ""
  description = "When set, every account in this AWS Organization may copy into the vaults."
}

variable "alert_email" {
  type        = string
  default     = ""
  description = "Optional email subscribed to primary-region backup failure alerts. Confirm the SNS subscription after apply."
}

variable "db2_instance_user" {
  type        = string
  default     = "db2inst1"
  description = "OS user that owns the DB2 instance, used by the quiesce and resume SSM documents."
}

variable "db2_database_name" {
  type        = string
  default     = "SAMPLE"
  description = "DB2 database name frozen before the EBS snapshot and resumed after it."
}

variable "additional_resource_arns" {
  type        = map(list(string))
  default     = {}
  description = "Extra resource ARNs to include for a workload key: ec2, db2, aurora, s3, dynamodb."
}

variable "tags" {
  type    = map(string)
  default = {}
}
