output "ecr_repo_url" {
  value       = module.nuke_bomber.ecr_repo_url
  description = "The URL of the ECR Repo to push your docker image to."
}
