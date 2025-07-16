provider "aws" {
  region = var.aws_region
}

#─────────────────────────────────────────────────────────────────────────────#
# Artifact Bucket & IAM Roles                                               #
#─────────────────────────────────────────────────────────────────────────────#
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "artifact_bucket" {
  bucket = "${var.project_name}-artifacts-${random_id.bucket_suffix.hex}"
}

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
    "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess",
  ])
  role       = aws_iam_role.codebuild_role.name
  policy_arn = each.value
}

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
    "arn:aws:iam::aws:policy/AWSCodePipelineFullAccess",
    "arn:aws:iam::aws:policy/AWSCodeBuildDeveloperAccess",
    "arn:aws:iam::aws:policy/AmazonS3FullAccess",
  ])
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = each.value
}

#─────────────────────────────────────────────────────────────────────────────#
# CI CodeBuild Project: Build, Scan & SonarCloud                            #
#─────────────────────────────────────────────────────────────────────────────#
resource "aws_codebuild_project" "ci_build" {
  name         = "${var.project_name}-ci"
  service_role = aws_iam_role.codebuild_role.arn

  artifacts { type = "CODEPIPELINE" }

  environment {
    compute_type                = "BUILD_GENERAL1_MEDIUM"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    environment_variable {
      name  = "SONAR_TOKEN"
      type  = "PARAMETER_STORE"
      value = var.sonar_token_param
    }
  }

  source       { type = "CODEPIPELINE" }
  build_timeout = 60
  build_spec    = file("buildspec-ci.yml")
}

#─────────────────────────────────────────────────────────────────────────────#
# Docker Build & Push (shared between CI/Docker stage)                       #
#─────────────────────────────────────────────────────────────────────────────#
resource "aws_codebuild_project" "docker_build" {
  name         = "${var.project_name}-docker"
  service_role = aws_iam_role.codebuild_role.arn

  artifacts       { type = "CODEPIPELINE" }
  build_timeout   = 60
  source          { type = "CODEPIPELINE" }

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
      type  = "PLAINTEXT"
      value = var.dockerhub_pass
    }
  }

  build_spec = file("buildspec-docker.yml")
}

#─────────────────────────────────────────────────────────────────────────────#
# CD CodeBuild Project: Ansible Deploy & ArgoCD Manifest Update              #
#─────────────────────────────────────────────────────────────────────────────#
resource "aws_codebuild_project" "cd_deploy" {
  name         = "${var.project_name}-cd"
  service_role = aws_iam_role.codebuild_role.arn

  artifacts       { type = "CODEPIPELINE" }
  build_timeout   = 60
  source          { type = "CODEPIPELINE" }

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

  build_spec = file("buildspec-cd.yml")
}

#─────────────────────────────────────────────────────────────────────────────#
# CodePipeline Definition                                                    #
#─────────────────────────────────────────────────────────────────────────────#
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
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["source_output"]
      configuration = {
        Owner      = var.github_owner
        Repo       = var.github_repo
        Branch     = var.github_branch
        OAuthToken = var.github_oauth_token
      }
    }
  }

  stage {
    name = "BuildAndScan"
    action {
      name             = "CI_Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      configuration = {
        ProjectName = aws_codebuild_project.ci_build.name
      }
    }
  }

  stage {
    name = "Docker"
    action {
      name            = "Docker_Build"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["source_output"]
      configuration = {
        ProjectName = aws_codebuild_project.docker_build.name
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
      input_artifacts = ["source_output"]
      configuration = {
        ProjectName = aws_codebuild_project.cd_deploy.name
      }
    }
  }
}
