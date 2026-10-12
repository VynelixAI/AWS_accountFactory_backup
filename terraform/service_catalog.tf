resource "aws_s3_bucket" "sc_templates" {
  bucket = "${var.project_name}-sc-templates-${local.account_id}"
  tags   = local.common_tags
}

resource "aws_s3_bucket_versioning" "sc_templates" {
  bucket = aws_s3_bucket.sc_templates.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "sc_templates" {
  bucket = aws_s3_bucket.sc_templates.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_public_access_block" "sc_templates" {
  bucket                  = aws_s3_bucket.sc_templates.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "product_template" {
  bucket = aws_s3_bucket.sc_templates.id
  key    = "account_request_product.yaml"
  source = "${path.module}/../cloudformation/account_request_product.yaml"
  etag   = filemd5("${path.module}/../cloudformation/account_request_product.yaml")
}

resource "aws_servicecatalog_portfolio" "account_factory" {
  name          = "Account Factory Portfolio"
  description   = "Request create/close of member accounts (no Control Tower)"
  provider_name = var.project_name
}

resource "aws_servicecatalog_product" "account_request" {
  name        = "Account Request"
  owner       = var.project_name
  description = "Opens a PR to create or close an AWS account via Organizations"
  type        = "CLOUD_FORMATION_TEMPLATE"

  provisioning_artifact_parameters {
    name         = "v1"
    description  = "Lambda opens PR; merge runs terraform apply"
    type         = "CLOUD_FORMATION_TEMPLATE"
    template_url = "https://${aws_s3_bucket.sc_templates.bucket_regional_domain_name}/${aws_s3_object.product_template.key}"
  }

  tags = local.common_tags
}

resource "aws_servicecatalog_product_portfolio_association" "account_request" {
  portfolio_id = aws_servicecatalog_portfolio.account_factory.id
  product_id   = aws_servicecatalog_product.account_request.id
}

resource "aws_servicecatalog_constraint" "launch" {
  portfolio_id = aws_servicecatalog_portfolio.account_factory.id
  product_id   = aws_servicecatalog_product.account_request.id
  type         = "LAUNCH"
  parameters = jsonencode({
    RoleArn = aws_iam_role.servicecatalog_launch.arn
  })
  depends_on = [aws_iam_role_policy.servicecatalog_launch]
}

resource "aws_servicecatalog_principal_portfolio_association" "launchers" {
  for_each      = toset(var.launch_role_principal_arns)
  portfolio_id  = aws_servicecatalog_portfolio.account_factory.id
  principal_arn = each.value
}
