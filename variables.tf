variable "aws_region" {
  type        = string
  description = "AWS Region to deploy resources"
  default     = "us-east-1"
}

variable "project_name" {
  type        = string
  description = "Project name prefix"
  default     = "comprehensive-production-ci-cd-pipeline"
}

variable "github_owner" {
  type        = string
  description = "GitHub repository owner"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name"
}

variable "github_branch" {
  type        = string
  description = "GitHub branch to track"
  default     = "main"
}

variable "codeconnection_arn" {
  type        = string
  description = "CodeStar connection ARN for GitHub integration"
}


variable "dockerhub_user" {
  type        = string
  description = "Docker Hub username"
}


variable "default_image_tag" {
  type        = string
  description = "Default Docker image tag for CD deploy if not passed"
  default     = "latest"
}
