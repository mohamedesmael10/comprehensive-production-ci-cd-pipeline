provider "aws" {
  region = var.aws_region
}

# ─────────────────────────────── #
# Artifact Bucket & IAM Roles      #
# ─────────────────────────────── #

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "artifact_bucket" {
  bucket        = "${var.project_name}-artifacts-${random_id.bucket_suffix.hex}"
  force_destroy = true
}

resource "aws_iam_policy" "codebuild_s3_access" {
  name   = "CodeBuildS3AccessPolicy"
  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = [
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
# CodeBuild IAM Role               #
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
    Version   = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["secretsmanager:GetSecretValue"],
      Resource = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:comp-prod-pipeline-secret*"
    }]
  })
}

# ─────────────────────────────── #
# EKS aws-auth Mapping Patch       #
# ─────────────────────────────── #

data "aws_caller_identity" "current" {}

data "aws_eks_cluster" "cluster" {
  name = var.eks_cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = var.eks_cluster_name
}

variable "worker_node_iam_role_name" {
  default = "eksctl-mohamed-esmael-cluster-v2-n-NodeInstanceRole-k0SZR6NuA9bJ"
}

data "aws_iam_role" "worker_node_role" {
  name = var.worker_node_iam_role_name
}

resource "aws_iam_role_policy_attachment" "attach_ebs_csi_policy" {
  role       = data.aws_iam_role.worker_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_iam_policy" "ebs_csi_driver_custom" {
  name        = "CustomAmazonEBSCSIDriverPolicy"
  description = "Minimum permissions for EBS CSI driver"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "ec2:AttachVolume",
        "ec2:CreateVolume",
        "ec2:DeleteVolume",
        "ec2:DetachVolume",
        "ec2:DescribeInstances",
        "ec2:DescribeVolumes",
        "ec2:DescribeAvailabilityZones"
      ],
      Resource = "*"
    }]
  })
}

resource "aws_iam_policy" "codebuild_eks_oidc_policy" {
  name        = "codebuild-eks-oidc-policy"
  description = "Allow CodeBuild to associate EKS OIDC provider and describe clusters"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:ListNodegroups",
          "eks:ListAddons"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "iam:GetOpenIDConnectProvider",
          "iam:CreateOpenIDConnectProvider",
          "iam:TagOpenIDConnectProvider"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_custom_ebs_csi_policy" {
  role       = data.aws_iam_role.worker_node_role.name
  policy_arn = aws_iam_policy.ebs_csi_driver_custom.arn
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

resource "null_resource" "make_patch_script_executable" {
  depends_on = [data.aws_eks_cluster.cluster]

  provisioner "local-exec" {
    command = "chmod +x ./patch_aws_auth.sh"
  }

  triggers = {
    always_run = timestamp()
  }
}

resource "null_resource" "patch_aws_auth" {
  depends_on = [null_resource.make_patch_script_executable]

  provisioner "local-exec" {
    command = "./patch_aws_auth.sh"
    environment = {
      AWS_DEFAULT_REGION = var.aws_region
    }
  }

  triggers = {
    role_arn = data.aws_caller_identity.current.account_id
  }
}

# ─────────────────────────────── #
# CodePipeline & CodeBuild Projects
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
    Version   = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = "codestar-connections:UseConnection",
      Resource = var.codeconnection_arn
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
    compute_type    = "BUILD_GENERAL1_MEDIUM"
    image           = "aws/codebuild/standard:7.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true

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
        FullRepositoryId = var.github_repo
        BranchName       = var.github_branch
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "CI_Build"
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
      }
    }
  }
}
