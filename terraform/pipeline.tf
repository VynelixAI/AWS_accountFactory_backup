resource "aws_s3_bucket" "pipeline_artifacts" {
  bucket = "${var.project_name}-pipeline-artifacts-${local.account_id}"
  tags   = local.common_tags
}

resource "aws_s3_bucket_versioning" "pipeline_artifacts" {
  bucket = aws_s3_bucket.pipeline_artifacts.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "pipeline_artifacts" {
  bucket = aws_s3_bucket.pipeline_artifacts.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_public_access_block" "pipeline_artifacts" {
  bucket                  = aws_s3_bucket.pipeline_artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# State for account-request Terraform applies
resource "aws_s3_bucket" "tf_state" {
  bucket = "${var.project_name}-account-tfstate-${local.account_id}"
  tags   = local.common_tags
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket                  = aws_s3_bucket.tf_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_codebuild_project" "apply" {
  name         = "${var.project_name}-account-request-apply"
  description  = "terraform apply account-request repo after merge to main"
  service_role = aws_iam_role.codebuild.arn

  artifacts { type = "CODEPIPELINE" }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    environment_variable {
      name  = "TF_STATE_BUCKET"
      value = aws_s3_bucket.tf_state.bucket
    }
    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = <<-EOF
      version: 0.2
      phases:
        install:
          runtime-versions:
            python: 3.12
          commands:
            - curl -fsSL https://releases.hashicorp.com/terraform/1.9.8/terraform_1.9.8_linux_amd64.zip -o /tmp/tf.zip
            - unzip -o /tmp/tf.zip -d /usr/local/bin
            - terraform version
        pre_build:
          commands:
            - |
              if [ ! -f backend.tf ]; then
                cat > backend.tf <<BACKEND
              terraform {
                backend "s3" {
                  bucket = "$TF_STATE_BUCKET"
                  key    = "account-request/terraform.tfstate"
                  region = "$AWS_DEFAULT_REGION"
                }
              }
              BACKEND
              fi
            - |
              if [ ! -f providers.tf ]; then
                cat > providers.tf <<'PROV'
              terraform {
                required_version = ">= 1.5.0"
                required_providers {
                  aws = { source = "hashicorp/aws", version = ">= 5.0" }
                }
              }
              provider "aws" {
                region = "us-east-1"
              }
              PROV
              fi
            - mkdir -p accounts
            - |
              # Terraform loads only *.tf in the working directory. Generated
              # account files live under accounts/ and are ignored unless copied up.
              loaded=0
              for f in accounts/*.tf; do
                [ -f "$f" ] || continue
                base=$(basename "$f")
                case "$base" in
                  backend.tf|providers.tf)
                    echo "Skipping $f so it does not replace the root backend or provider"
                    ;;
                  *)
                    cp -f "$f" .
                    echo "Loaded $f into the root module"
                    loaded=1
                    ;;
                esac
              done
              if [ "$loaded" -eq 0 ]; then
                echo "No account Terraform files under accounts/"
              fi
            - echo "Root module Terraform files:"
            - find . -maxdepth 1 -name '*.tf' | sort
        build:
          commands:
            - terraform init -input=false
            - |
              set -eu
              # CloseAccount is accepted immediately, but the account stays in
              # the organization until AWS finishes closing it. Terraform waits
              # for that and fails the build, so close here and drop state.
              addrs=$(terraform state list 2>/dev/null | grep '^aws_organizations_account\.' || true)
              for addr in $addrs; do
                name=$(terraform state show -no-color "$addr" | awk -F'"' '/^[[:space:]]*name[[:space:]]*=/{print $2; exit}')
                id=$(terraform state show -no-color "$addr" | awk -F'"' '/^[[:space:]]*id[[:space:]]*=/{print $2; exit}')
                if [ -z "$name" ] || [ -z "$id" ]; then
                  echo "Could not read name or id for $addr"
                  exit 1
                fi
                if [ -f "accounts/$${name}.tf" ]; then
                  continue
                fi
                echo "accounts/$${name}.tf was removed; closing account $id"
                if aws organizations close-account --account-id "$id"; then
                  echo "CloseAccount accepted for $id"
                else
                  state=$(aws organizations describe-account --account-id "$id" --query 'Account.State' --output text)
                  status=$(aws organizations describe-account --account-id "$id" --query 'Account.Status' --output text)
                  echo "CloseAccount returned an error; status=$status state=$state"
                  case "$state" in
                    CLOSED|PENDING_CLOSURE|SUSPENDED) ;;
                    *)
                      case "$status" in
                        SUSPENDED) ;;
                        *)
                          echo "Account $id is still open; leaving $addr in Terraform state"
                          exit 1
                          ;;
                      esac
                      ;;
                  esac
                fi
                terraform state rm "$addr"
              done
            - terraform validate
            - terraform plan -input=false -out=tfplan
            - terraform apply -input=false -auto-approve tfplan
      artifacts:
        files:
          - '**/*'
    EOF
  }

  logs_config {
    cloudwatch_logs {
      group_name = "/aws/codebuild/${var.project_name}-account-request-apply"
    }
  }

  tags = local.common_tags
}

resource "aws_codepipeline" "account_request" {
  name     = "${var.project_name}-account-request-pipeline"
  role_arn = aws_iam_role.codepipeline.arn

  artifact_store {
    location = aws_s3_bucket.pipeline_artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["source_output"]
      configuration = {
        RepositoryName       = var.account_request_repo_name
        BranchName           = var.default_branch
        PollForSourceChanges = "false"
      }
    }
  }

  stage {
    name = "Apply"
    action {
      name            = "TerraformApply"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["source_output"]
      configuration = {
        ProjectName = aws_codebuild_project.apply.name
      }
    }
  }

  tags = local.common_tags

  depends_on = [aws_iam_role_policy.codepipeline]
}

# Approving the pull request merges it. This rule starts the pipeline when main changes.
resource "aws_cloudwatch_event_rule" "main_branch" {
  name        = "${var.project_name}-account-request-main"
  description = "Start account-request pipeline when main is updated"

  event_pattern = jsonencode({
    source      = ["aws.codecommit"]
    detail-type = ["CodeCommit Repository State Change"]
    resources   = ["arn:${local.partition}:codecommit:${local.region}:${local.account_id}:${var.account_request_repo_name}"]
    detail = {
      event         = ["referenceCreated", "referenceUpdated"]
      referenceType = ["branch"]
      referenceName = [var.default_branch]
    }
  })
}

resource "aws_cloudwatch_event_target" "pipeline" {
  rule      = aws_cloudwatch_event_rule.main_branch.name
  target_id = "StartAccountRequestPipeline"
  arn       = aws_codepipeline.account_request.arn
  role_arn  = aws_iam_role.pipeline_events.arn

  depends_on = [aws_iam_role_policy.pipeline_events]
}

resource "aws_cloudwatch_event_rule" "pr_approved" {
  name        = "${var.project_name}-pr-approved"
  description = "Merge an account-request pull request after it is approved"

  event_pattern = jsonencode({
    source      = ["aws.codecommit"]
    detail-type = ["CodeCommit Pull Request State Change"]
    resources   = ["arn:${local.partition}:codecommit:${local.region}:${local.account_id}:${var.account_request_repo_name}"]
    detail = {
      event          = ["pullRequestApprovalStateChanged"]
      approvalStatus = ["APPROVE"]
    }
  })
}

resource "aws_cloudwatch_event_target" "merge_on_approval" {
  rule      = aws_cloudwatch_event_rule.pr_approved.name
  target_id = "MergeApprovedPullRequest"
  arn       = aws_lambda_function.account_request.arn
}

resource "aws_lambda_permission" "allow_pr_approval_events" {
  statement_id  = "AllowEventBridgePrApproval"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.account_request.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.pr_approved.arn
}
