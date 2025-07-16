variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project prefix for resources"
  type        = string
  default     = "comp-prod-pipeline"
}

variable "github_owner" {
  description = "GitHub user/org"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

variable "github_branch" {
  description = "Branch to build/deploy"
  type        = string
  default     = "git-actions-pipeline"
}

variable "github_oauth_token" {
  description = "GitHub OAuth token"
  type        = string
  sensitive   = true
}

variable "dockerhub_user" {
  description = "Docker Hub username"
  type        = string
}

variable "dockerhub_pass" {
  description = "Docker Hub password"
  type        = string
  sensitive   = true
}

variable "sonar_token_param" {
  description = "SSM Parameter name for Sonar token"
  type        = string
  default     = "/sonar/token"
}

variable "default_image_tag" {
  description = "Default image tag for CD"
  type        = string
  default     = "latest"
}
