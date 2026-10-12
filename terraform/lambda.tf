resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.lambda_function_name}"
  retention_in_days = 14
}

resource "aws_lambda_function" "account_request" {
  function_name = local.lambda_function_name
  role          = aws_iam_role.lambda.arn
  handler       = "handler.lambda_handler"
  runtime       = "python3.12"
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size

  filename         = local.lambda_zip_path
  source_code_hash = fileexists(local.lambda_zip_path) ? filebase64sha256(local.lambda_zip_path) : null

  environment {
    variables = {
      ACCOUNT_REQUEST_REPO_NAME = var.account_request_repo_name
      DEFAULT_BRANCH            = var.default_branch
      PARENT_OU_ID              = var.parent_ou_id
      LOG_LEVEL                 = "INFO"
      AWS_REGION_NAME           = var.aws_region
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda, aws_iam_role_policy.lambda]
}

resource "aws_lambda_permission" "allow_servicecatalog" {
  statement_id  = "AllowServiceCatalogInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.account_request.function_name
  principal     = "servicecatalog.amazonaws.com"
}

resource "aws_lambda_permission" "allow_cloudformation" {
  statement_id  = "AllowCloudFormationInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.account_request.function_name
  principal     = "cloudformation.amazonaws.com"
}
