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

variable "ecr_repo_uri" {
  type        = string
  description = "Docker Hub username"
}

variable "ecr_repo_name" {
  description = "ECR repository name"
  type        = string
}

variable "eks_cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "eks_service_name" {
  description = "Kubernetes deployment/service name"
  type        = string
}

variable "eks_namespace" {
  description = "Kubernetes namespace"
  type        = string
  default     = "default"
}
