provider "aws" {
  region = var.aws_region
}

# ─────────────────────────────── #
# Artifact Bucket & IAM Roles
# ─────────────────────────────── #

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "artifact_bucket" {
  bucket        = "${var.project_name}-artifacts-${random_id.bucket_suffix.hex}"
  force_destroy = true
}

resource "aws_iam_policy" "codebuild_s3_access" {
  name = "CodeBuildS3AccessPolicy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "s3:PutObject",
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:GetBucketAcl",
        "s3:GetBucketLocation"
      ],
      Resource = [
        "arn:aws:s3:::${var.project_name}-artifacts-*",
        "arn:aws:s3:::${var.project_name}-artifacts-*/*"
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "codebuild_s3_access_attachment" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = aws_iam_policy.codebuild_s3_access.arn
}

# ─────────────────────────────── #
# CodeBuild IAM Role
# ─────────────────────────────── #

data "aws_iam_policy_document" "codebuild_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codebuild_role" {
  name               = "${var.project_name}-codebuild-role"
  assume_role_policy = data.aws_iam_policy_document.codebuild_assume.json
}

resource "aws_iam_role_policy_attachment" "codebuild_policies" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser",
    "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
  ])
  role       = aws_iam_role.codebuild_role.name
  policy_arn = each.value
}

resource "aws_iam_role_policy" "codebuild_secrets_access" {
  name = "AllowSecretsManagerAccess"
  role = aws_iam_role.codebuild_role.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = ["secretsmanager:GetSecretValue"],
      Resource = "arn:aws:secretsmanager:us-east-1:025066251600:secret:comp-prod-pipeline-secret*"
    }]
  })
}

# ─────────────────────────────── #
# CodePipeline IAM Role
# ─────────────────────────────── #

data "aws_iam_policy_document" "codepipeline_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codepipeline_role" {
  name               = "${var.project_name}-codepipeline-role"
  assume_role_policy = data.aws_iam_policy_document.codepipeline_assume.json
}

resource "aws_iam_role_policy_attachment" "codepipeline_policies" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AWSCodeBuildDeveloperAccess",
    "arn:aws:iam::aws:policy/AmazonS3FullAccess",
    "arn:aws:iam::aws:policy/AWSCodePipeline_ReadOnlyAccess",
    "arn:aws:iam::aws:policy/AWSCodeStarFullAccess",
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  ])
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = each.value
}

resource "aws_iam_role_policy" "codepipeline_connection" {
  name = "AllowUseCodeStarConnection"
  role = aws_iam_role.codepipeline_role.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = "codestar-connections:UseConnection",
      Resource = "arn:aws:codeconnections:us-east-1:025066251600:connection/ba2ef8c3-98a9-48f9-949c-e8353efeb72d"
    }]
  })
}

# ─────────────────────────────── #
# CodeBuild Projects
# ─────────────────────────────── #

resource "aws_codebuild_project" "ci_build" {
  name         = "${var.project_name}-ci"
  service_role = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_LARGE"
    image           = "aws/codebuild/standard:7.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true

    environment_variable {
      name  = "DOCKERHUB_USER"
      type  = "PLAINTEXT"
      value = var.dockerhub_user
    }

    environment_variable {
      name  = "DOCKERHUB_PASS"
      type  = "SECRETS_MANAGER"
      value = "comp-prod-pipeline-secret:dockerhub_pass"
    }

    environment_variable {
      name  = "SONAR_TOKEN"
      type  = "SECRETS_MANAGER"
      value = "comp-prod-pipeline-secret:sonar_token_param"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = file("buildspec-ci.yml")
  }

  build_timeout = 60
}

resource "aws_codebuild_project" "cd_deploy" {
  name         = "${var.project_name}-cd"
  service_role = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = "BUILD_GENERAL1_MEDIUM"
    image        = "aws/codebuild/standard:7.0"
    type         = "LINUX_CONTAINER"

    environment_variable {
      name  = "IMAGE_TAG"
      type  = "PLAINTEXT"
      value = var.default_image_tag
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = file("buildspec-cd.yml")
  }

  build_timeout = 60
}

# ─────────────────────────────── #
# CodePipeline
# ─────────────────────────────── #

resource "aws_codepipeline" "app_pipeline" {
  name     = var.project_name
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.artifact_bucket.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "GitHub_Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = var.codeconnection_arn
        FullRepositoryId = "${var.github_owner}/${var.github_repo}"
        BranchName       = var.github_branch
        DetectChanges    = "true"
      }
    }
  }

  stage {
    name = "BuildAndDockerize"

    action {
      name             = "CI_Docker_Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]

      configuration = {
        ProjectName = aws_codebuild_project.ci_build.name
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "CD_Deploy"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["build_output"]

      configuration = {
        ProjectName = aws_codebuild_project.cd_deploy.name
        EnvironmentVariables = jsonencode([
          { name = "IMAGE_TAG", type = "CODEPIPELINE_VARIABLE", value = "IMAGE_TAG" },
          { name = "APP_NAME", type = "PLAINTEXT", value = var.project_name },
          { name = "DOCKERHUB_USER", type = "PLAINTEXT", value = var.dockerhub_user },
          { name = "AWS_REGION", type = "PLAINTEXT", value = var.aws_region },
          { name = "ECR_REPO_URI", type = "PLAINTEXT", value = var.ecr_repo_uri }
        ])
      }
    }
  }
}

# ─────────────────────────────── #
# Lambda for EKS Service Update
# ─────────────────────────────── #

data "aws_lambda_function" "update_eks_service" {
  function_name = "ECSImageUpdateLambda"
}


resource "aws_iam_role" "lambda_exec_role" {
  name = "${var.project_name}-lambda-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
      Effect = "Allow",
      Sid    = ""
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_exec_policies" {
  for_each = toset([
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  ])
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = each.value
}

# ─────────────────────────────── #
# EventBridge Rule (Trigger Lambda on ECR Push)
# ─────────────────────────────── #

resource "aws_cloudwatch_event_rule" "ecr_image_push" {
  name        = "${var.project_name}-ecr-push-rule"
  description = "Trigger Lambda on new image push to ECR"
  event_pattern = jsonencode({
    source      = ["aws.ecr"],
    "detail-type" = ["ECR Image Action"],
    detail      = {
      "action-type"     = ["PUSH"],
      "repository-name" = [var.ecr_repo_name]
    }
  })
}

resource "aws_cloudwatch_event_target" "ecr_to_lambda" {
  rule      = aws_cloudwatch_event_rule.ecr_image_push.name
  target_id = "TriggerLambdaFunction"
  arn       = data.aws_lambda_function.update_eks_service.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = data.aws_lambda_function.update_eks_service.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ecr_image_push.arn
}
