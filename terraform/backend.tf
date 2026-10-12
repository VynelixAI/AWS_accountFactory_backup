# Optional remote state — uncomment after creating the bucket:
#
# terraform {
#   backend "s3" {
#     bucket  = "account-factory-tfstate-ACCOUNT_ID"
#     key     = "account-factory-no-ct/terraform.tfstate"
#     region  = "us-east-1"
#     encrypt = true
#   }
# }
