resource "aws_iam_role" "lambda" {
  name = "${var.project_name}-account-request-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "lambda.amazonaws.com"
      }

      Action = "sts:AssumeRole"
    }]
  })
}


resource "aws_iam_role_policy" "lambda" {
  name = "${var.project_name}-lambda-policy"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [

      {
        Sid    = "Logs"
        Effect = "Allow"

        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]

        Resource = "arn:${local.partition}:logs:${local.region}:${local.account_id}:*"
      },

      {
        Sid    = "Organizations"
        Effect = "Allow"

        Action = [
          "organizations:ListRoots",
          "organizations:ListOrganizationalUnitsForParent",
          "organizations:DescribeOrganizationalUnit",
          "organizations:CreateOrganizationalUnit",
          "organizations:ListAccountsForParent",
          "organizations:DescribeAccount",
          "organizations:CreateAccount",
          "organizations:DescribeCreateAccountStatus",
          "organizations:MoveAccount",
          "organizations:CloseAccount"
        ]

        Resource = "*"
      },

      {
        Sid    = "CodeCommit"
        Effect = "Allow"

        Action = [
          "codecommit:GetRepository",
          "codecommit:GetBranch",
          "codecommit:ListBranches",
          "codecommit:CreateBranch",
          "codecommit:GetFile",
          "codecommit:GetFolder",
          "codecommit:PutFile",
          "codecommit:DeleteFile",
          "codecommit:CreateCommit",
          "codecommit:GetCommit",
          "codecommit:CreatePullRequest",
          "codecommit:GetPullRequest",
          "codecommit:ListPullRequests",
          "codecommit:EvaluatePullRequestApprovalRules",
          "codecommit:MergePullRequestByFastForward",
          "codecommit:MergePullRequestByThreeWay",
          "codecommit:GetMergeConflicts",
          "codecommit:GetMergeOptions",
          "codecommit:GetMergeCommit",
          "codecommit:GitPull",
          "codecommit:GitPush"
        ]

        Resource = "arn:${local.partition}:codecommit:${local.region}:${local.account_id}:${var.account_request_repo_name}"
      }
    ]
  })
}


resource "aws_iam_role" "servicecatalog_launch" {
  name = "${var.project_name}-sc-launch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "servicecatalog.amazonaws.com"
      }

      Action = [
        "sts:AssumeRole",
        "sts:TagSession"
      ]
    }]
  })
}


resource "aws_iam_role_policy" "servicecatalog_launch" {
  name = "${var.project_name}-sc-launch-policy"
  role = aws_iam_role.servicecatalog_launch.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [

      {
        Sid    = "CloudFormation"
        Effect = "Allow"

        Action = [
          "cloudformation:CreateStack",
          "cloudformation:DeleteStack",
          "cloudformation:DescribeStacks",
          "cloudformation:DescribeStackEvents",
          "cloudformation:GetTemplate",
          "cloudformation:GetTemplateSummary",
          "cloudformation:ListStackResources",
          "cloudformation:UpdateStack",
          "cloudformation:CreateChangeSet",
          "cloudformation:DescribeChangeSet",
          "cloudformation:ExecuteChangeSet",
          "cloudformation:DeleteChangeSet",
          "cloudformation:SetStackPolicy",
          "cloudformation:DescribeStackResources",
          "cloudformation:ValidateTemplate"
        ]

        Resource = "*"
      },

      {
        Sid    = "InvokeAccountRequestLambda"
        Effect = "Allow"

        Action = [
          "lambda:InvokeFunction"
        ]

        Resource = aws_lambda_function.account_request.arn
      },

      {
        Sid    = "ListTemplateBuckets"
        Effect = "Allow"

        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]

        Resource = [
          aws_s3_bucket.sc_templates.arn,
          "arn:${local.partition}:s3:::cf-templates-*",
          "arn:${local.partition}:s3:::sc-*"
        ]
      },

      {
        Sid    = "ReadTemplateObjects"
        Effect = "Allow"

        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetObjectTagging"
        ]

        Resource = [
          "${aws_s3_bucket.sc_templates.arn}/*",
          "arn:${local.partition}:s3:::cf-templates-*/*",
          "arn:${local.partition}:s3:::sc-*/*"
        ]
      },

      {
        Sid    = "ReadServiceCatalogProvisioningArtifacts"
        Effect = "Allow"

        Action = [
          "s3:GetObject"
        ]

        Resource = "*"

        Condition = {
          StringEquals = {
            "s3:ExistingObjectTag/servicecatalog:provisioning" = "true"
          }
        }
      }
    ]
  })
}


resource "aws_iam_role" "codepipeline" {
  name = "${var.project_name}-codepipeline"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "codepipeline.amazonaws.com"
      }

      Action = "sts:AssumeRole"
    }]
  })
}


resource "aws_iam_role_policy" "codepipeline" {
  name = "${var.project_name}-codepipeline-policy"
  role = aws_iam_role.codepipeline.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [

      {
        Sid    = "CodeCommit"
        Effect = "Allow"

        Action = [
          "codecommit:GetBranch",
          "codecommit:GetCommit",
          "codecommit:UploadArchive",
          "codecommit:GetUploadArchiveStatus",
          "codecommit:CancelUploadArchive",
          "codecommit:GetRepository"
        ]

        Resource = "arn:${local.partition}:codecommit:${local.region}:${local.account_id}:${var.account_request_repo_name}"
      },

      {
        Sid    = "CodeBuild"
        Effect = "Allow"

        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild"
        ]

        Resource = aws_codebuild_project.apply.arn
      },

      {
        Sid    = "PipelineArtifacts"
        Effect = "Allow"

        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:GetBucketVersioning"
        ]

        Resource = [
          aws_s3_bucket.pipeline_artifacts.arn,
          "${aws_s3_bucket.pipeline_artifacts.arn}/*"
        ]
      }
    ]
  })
}


resource "aws_iam_role" "pipeline_events" {
  name = "${var.project_name}-pipeline-events"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "events.amazonaws.com"
      }

      Action = "sts:AssumeRole"
    }]
  })
}


resource "aws_iam_role_policy" "pipeline_events" {
  name = "${var.project_name}-pipeline-events"
  role = aws_iam_role.pipeline_events.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Sid      = "StartPipeline"
      Effect   = "Allow"
      Action   = "codepipeline:StartPipelineExecution"
      Resource = aws_codepipeline.account_request.arn
    }]
  })
}


resource "aws_iam_role" "codebuild" {
  name = "${var.project_name}-codebuild"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "codebuild.amazonaws.com"
      }

      Action = "sts:AssumeRole"
    }]
  })
}


resource "aws_iam_role_policy" "codebuild" {
  name = "${var.project_name}-codebuild-policy"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [

      # CloudWatch Logs
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"

        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]

        Resource = "arn:${local.partition}:logs:${local.region}:${local.account_id}:*"
      },

      # Pipeline artifact objects
      {
        Sid    = "PipelineArtifactObjects"
        Effect = "Allow"

        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:DeleteObject"
        ]

        Resource = "${aws_s3_bucket.pipeline_artifacts.arn}/*"
      },

      # Pipeline artifact bucket
      {
        Sid    = "PipelineArtifactBucket"
        Effect = "Allow"

        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetBucketVersioning"
        ]

        Resource = aws_s3_bucket.pipeline_artifacts.arn
      },

      # Terraform state objects
      {
        Sid    = "TerraformStateObjects"
        Effect = "Allow"

        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:DeleteObject"
        ]

        Resource = "${aws_s3_bucket.tf_state.arn}/account-request/*"
      },

      # Terraform state bucket
      {
        Sid    = "TerraformStateBucket"
        Effect = "Allow"

        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetBucketVersioning"
        ]

        Resource = aws_s3_bucket.tf_state.arn

        Condition = {
          StringLike = {
            "s3:prefix" = [
              "account-request/*"
            ]
          }
        }
      },

      # CodeCommit
      {
        Sid    = "CodeCommit"
        Effect = "Allow"

        Action = [
          "codecommit:GitPull"
        ]

        Resource = "arn:${local.partition}:codecommit:${local.region}:${local.account_id}:${var.account_request_repo_name}"
      },

      # AWS Organizations
      {
        Sid    = "OrganizationsForApply"
        Effect = "Allow"

        Action = [
          "organizations:CreateAccount",
          "organizations:DescribeCreateAccountStatus",
          "organizations:DescribeAccount",
          "organizations:ListAccounts",
          "organizations:ListParents",
          "organizations:ListRoots",
          "organizations:ListOrganizationalUnitsForParent",
          "organizations:MoveAccount",
          "organizations:CloseAccount",
          "organizations:DescribeOrganizationalUnit",
          "organizations:DescribeOrganization",
          "organizations:TagResource",
          "organizations:UntagResource",
          "organizations:ListTagsForResource"
        ]

        Resource = "*"
      },

      # Organizations service-linked role
      {
        Sid    = "OrganizationsServiceLinkedRole"
        Effect = "Allow"

        Action = [
          "iam:CreateServiceLinkedRole"
        ]

        Resource = "*"

        Condition = {
          StringEquals = {
            "iam:AWSServiceName" = "organizations.amazonaws.com"
          }
        }
      }
    ]
  })
}
