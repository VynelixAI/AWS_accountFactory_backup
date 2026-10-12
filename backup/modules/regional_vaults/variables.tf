variable "name_prefix" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "workloads" {
  type = set(string)
}

variable "enable_vault_lock" {
  type = bool
}

variable "vault_lock_changeable_for_days" {
  type    = number
  default = null
}

variable "min_retention_days" {
  type = number
}

variable "max_retention_days" {
  type = number
}

variable "workload_account_ids" {
  type = list(string)
}

variable "organization_id" {
  type = string
}

variable "partition" {
  type = string
}

variable "tags" {
  type = map(string)
}

variable "resource_type_opt_in" {
  type = map(bool)
}
