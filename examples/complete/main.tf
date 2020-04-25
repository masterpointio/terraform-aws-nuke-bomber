provider "aws" {
  region = "us-east-1"
}

module "nuke_bomber" {
  source    = "../.."
  namespace = var.namespace

  # NOTE: 5 minutes is way too often. This is just for testing / example purposes.
  schedule_expression = "rate(5 minutes)"

  # NOTE: When you've tested using dry runs, enable the following to actually execute the resource deletion.
  # command = ["-c", "/home/aws-nuke/nuke-config.yml", "--force", "--force-sleep", "3", "--no-dry-run"]
}
