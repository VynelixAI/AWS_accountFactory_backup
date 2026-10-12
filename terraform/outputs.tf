output "lambda_function_arn" {
  description = "Paste this as ServiceToken when launching the Service Catalog product"
  value       = aws_lambda_function.account_request.arn
}

output "lambda_function_name" {
  value = aws_lambda_function.account_request.function_name
}

output "codecommit_repo_name" {
  value = var.account_request_repo_name
}

output "codecommit_clone_url_http" {
  value = try(aws_codecommit_repository.account_request[0].clone_url_http, null)
}

output "pipeline_name" {
  value = aws_codepipeline.account_request.name
}

output "service_catalog_portfolio_id" {
  value = aws_servicecatalog_portfolio.account_factory.id
}

output "service_catalog_product_id" {
  value = aws_servicecatalog_product.account_request.id
}

output "tf_state_bucket" {
  description = "S3 bucket used by the pipeline for account Terraform state"
  value       = aws_s3_bucket.tf_state.bucket
}

output "parent_ou_id" {
  value = var.parent_ou_id
}
