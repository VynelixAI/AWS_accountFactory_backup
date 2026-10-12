variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region"
}

variable "project_name" {
  type        = string
  default     = "account-factory"
  description = "Name prefix for resources"
}

variable "environment" {
  type    = string
  default = "test"
}

variable "parent_ou_id" {
  type        = string
  description = "Organizations Root ID (r-xxxx) or parent OU under which new OUs are created"
}

variable "account_request_repo_name" {
  type    = string
  default = "account-request"
}

variable "default_branch" {
  type    = string
  default = "main"
}

variable "lambda_timeout" {
  type    = number
  default = 300
}

variable "lambda_memory_size" {
  type    = number
  default = 512
}

variable "create_codecommit_repo" {
  type    = bool
  default = true
}

variable "launch_role_principal_arns" {
  type        = list(string)
  default     = []
  description = "IAM users/roles allowed to launch the Service Catalog product"
}

variable "tags" {
  type    = map(string)
  default = {}
}
