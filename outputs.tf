output "ecr_repo_url" {
  value       = aws_ecr_repository.default.repository_url
  description = "The URL of the ECR Repo to push your docker image to."
}
