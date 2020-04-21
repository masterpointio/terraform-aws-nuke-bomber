provider "aws" {
  region = "us-east-1"
}

module "nuke_bomber" {
  source              = "../.."
  namespace           = var.namespace
  schedule_expression = "rate(5 minutes)"
}
