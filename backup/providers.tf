provider "aws" {
  region = var.primary_region
}

provider "aws" {
  alias  = "secondary"
  region = var.secondary_region
}

provider "aws" {
  alias  = "tertiary"
  region = var.tertiary_region
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
