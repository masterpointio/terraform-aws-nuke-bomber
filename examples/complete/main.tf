provider "aws" {
  region = "us-east-1"
}

module "nuke_bomber" {
  source    = "../.."
  namespace = var.namespace

  # NOTE: 5 minutes is way too often. This is just for testing / example purposes.
  # Change this once you're not running drills!
  schedule_expression = "rate(5 minutes)"
}
