output "artifact_bucket" {
  value = aws_s3_bucket.artifact_bucket.bucket
}

output "codepipeline_url" {
  value = "https://${var.aws_region}.console.aws.amazon.com/codesuite/codepipeline/pipelines/${aws_codepipeline.app_pipeline.name}/view"
}
