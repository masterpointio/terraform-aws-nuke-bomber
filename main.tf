/**
 * [![Masterpoint Logo](https://i.imgur.com/RDLnuQO.png)](https://masterpoint.io)
 *
 * # terraform-aws-nuke-bomber
 *
 * :airplane:
 * :bomb:
 * :cloud:
 *
 * This terraform module deploys a VPC, ECS Cluster, and Scheduled ECS Fargate Task to repeatedly execute [`aws-nuke`](https://github.com/rebuy-de/aws-nuke) (removes all resources) against the running AWS Account. This is intended for usage in "Test Accounts" where developers or CI / CD are typically deploying infrastructure that needs to be cleaned up often, otherwise it would incur unnecessary costs.
 *
 * ##### NOTE: As is stated multiple times on the `aws-nuke` repo, this project should similarly be used with extreme caution for obvious reasons. You should explicitly add all AWS Account IDs that you *don't* want nuked into oblivion to the exclude section of your `nuke-config.yml` file and be sure to properly configure the filters in that same file to keep around any resources which you don't want removed. Always run this project in dry-run mode first (on by default) and only turn on `NOT_A_DRILL` when you're sure you've configured everything correctly to your liking. This project and its maintainers are not responsible for not following those steps.
 *
 * Big shout out to the folks [@cloudposse](https://github.com/cloudposse), who have awesome open source modules which this repo uses heavily!
 *
 * ## Usage
 *
 * First, deploy the module:
 *
 * ```hcl
 * provider "aws" {
 *   region = "us-east-1"
 * }
 *
 * module "nuke_bomber" {
 *   source    = "git::https://github.com/masterpointio/terraform-aws-nuke-bomber.git?ref=tags/0.1.0"
 *   namespace = var.namespace
 *
 *   # NOTE: 5 minutes is way too often. This is just for testing / example purposes.
 *   # Change this once you're not running drills!
 *   schedule_expression = "rate(5 minutes)"
 * }
 * ```
 *
 * Next, to get the ECS Task running, you need to do the following:
 *
 * 1. Copy nuke-config example:
 *   - `cp nuke-config.yml.example nuke-config.yml`
 * 1. Replace your `nuke-config.yml` `TODO_` fields with your Account ID, Region, and Production Account ID(s).
 * 1. Check over the config. Make sure to exclude or filter out anything you don't want removed from your account!
 * 1. From the root directory, build the docker image:
 *  - `docker build . -t bomber:latest --build-arg ACCOUNT_ALIAS=your-account-alias`
 * 1. Grab the ECR Repo URL from the module output:
 *   - `export ECR_REPO=$(terraform output ecr_repo_url)`
 * 1. Tag your bomber image:
 *   - `docker tag bomber:latest ${ECR_REPO}:latest`
 * 1. Push your bomber image to ECR:
 *   - `docker push ${ECR_REPO}:latest`
 *   - NOTE: Make sure you've got an ECR Push token via:
 *     - `eval $(aws ecr get-login --region us-east-1 --no-include-email)`
 * 1. Check out your logs in CloudWatch to watch the bomb drop!
 *
 * Noticed that nothing got deleted even though your bomber should've nuked the account? Huh, looks like that was just a drill... try building again with the `NOT_A_DRILL` arg and then tag and push your image again:
 * ```bash
 * docker build . -t bomber:latest --build-arg ACCOUNT_ALIAS=your-account-alias --build-arg NOT_A_DRILL=true
 * ```
 */

terraform {
  required_version = ">= 0.12"
  required_providers {
    aws = "~> 2.0"
  }
}

module "base_label" {
  source    = "git::https://github.com/cloudposse/terraform-null-label.git?ref=tags/0.16.0"
  namespace = var.namespace
  stage     = var.stage
  name      = var.name
  tags      = merge({ Protected = "true" }, var.tags)
}

module "task_label" {
  source     = "git::https://github.com/cloudposse/terraform-null-label.git?ref=tags/0.16.0"
  namespace  = var.namespace
  stage      = var.stage
  name       = var.name
  attributes = ["task"]
  tags       = merge({ Protected = "true" }, var.tags)
}

module "exec_label" {
  source     = "git::https://github.com/cloudposse/terraform-null-label.git?ref=tags/0.16.0"
  namespace  = var.namespace
  stage      = var.stage
  name       = var.name
  attributes = ["exec"]
  tags       = merge({ Protected = "true" }, var.tags)
}

module "cloudwatch_label" {
  source     = "git::https://github.com/cloudposse/terraform-null-label.git?ref=tags/0.16.0"
  namespace  = var.namespace
  stage      = var.stage
  name       = var.name
  attributes = ["cloudwatch"]
  tags       = merge({ Protected = "true" }, var.tags)
}

module "event_label" {
  source     = "git::https://github.com/cloudposse/terraform-null-label.git?ref=tags/0.16.0"
  namespace  = var.namespace
  stage      = var.stage
  name       = var.name
  attributes = ["event"]
  tags       = merge({ Protected = "true" }, var.tags)
}

module "log_group_label" {
  source     = "git::https://github.com/cloudposse/terraform-null-label.git?ref=tags/0.16.0"
  namespace  = var.namespace
  stage      = var.stage
  name       = var.name
  attributes = ["logs"]
  tags       = merge({ Protected = "true" }, var.tags)
}

## NETWORK
###########

module "vpc" {
  source     = "git::https://github.com/cloudposse/terraform-aws-vpc.git?ref=tags/0.10.0"
  namespace  = var.namespace
  stage      = var.stage
  name       = var.name
  cidr_block = var.vpc_cidr_block
  tags       = module.base_label.tags
}

module "subnets" {
  source               = "git::https://github.com/cloudposse/terraform-aws-dynamic-subnets.git?ref=tags/0.19.0"
  availability_zones   = var.availability_zones
  namespace            = var.namespace
  stage                = var.stage
  vpc_id               = module.vpc.vpc_id
  igw_id               = module.vpc.igw_id
  cidr_block           = module.vpc.vpc_cidr_block
  nat_gateway_enabled  = var.nat_gateway_enabled
  nat_instance_enabled = ! var.nat_gateway_enabled
  tags                 = module.base_label.tags
}

# We create a new Main Route Table, so we can ensure it has tags (to allow filtering).
resource "aws_route_table" "new_main" {
  vpc_id = module.vpc.vpc_id
  tags   = module.base_label.tags
}

resource "aws_main_route_table_association" "default" {
  vpc_id         = module.vpc.vpc_id
  route_table_id = aws_route_table.new_main.id
}

resource "aws_security_group_rule" "allow_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.vpc.vpc_default_security_group_id
}

## SUPPORTING
##############

resource "aws_cloudwatch_log_group" "default" {
  name              = module.log_group_label.id
  retention_in_days = var.log_retention_in_days
  tags              = module.log_group_label.tags
}

resource "aws_ecr_repository" "default" {
  name = module.base_label.id
  tags = module.base_label.tags
}

## CloudWatch Events
#####################

resource "aws_cloudwatch_event_rule" "default" {
  name        = module.event_label.id
  description = "Event rule which triggers every ${var.schedule_expression} to invoke the Nuke Bomber ECS Fargate Task."
  is_enabled  = true

  # Example, "cron(0 20 * * ? *)" or "rate(5 minutes)".
  # https://docs.aws.amazon.com/AmazonCloudWatch/latest/events/ScheduledEvents.html
  schedule_expression = var.schedule_expression
  tags                = module.event_label.tags
}

resource "aws_cloudwatch_event_target" "default" {
  target_id = "${module.base_label.id}-run-task"
  arn       = aws_ecs_cluster.default.arn
  rule      = aws_cloudwatch_event_rule.default.name
  role_arn  = aws_iam_role.ecs_events.arn

  ecs_target {
    launch_type         = "FARGATE"
    task_count          = 1
    task_definition_arn = aws_ecs_task_definition.default.arn
    platform_version    = "LATEST"
    network_configuration {
      assign_public_ip = false
      security_groups  = [module.vpc.vpc_default_security_group_id]
      subnets          = module.subnets.private_subnet_ids
    }
  }
}

## ECS
#######

resource "aws_ecs_cluster" "default" {
  name = module.base_label.id
  tags = module.base_label.tags
}

module "container_definition" {
  source                       = "git::https://github.com/cloudposse/terraform-aws-ecs-container-definition.git?ref=tags/0.23.0"
  container_name               = module.base_label.id
  command                      = var.command
  container_image              = "${aws_ecr_repository.default.repository_url}:latest"
  container_memory             = var.container_memory
  container_memory_reservation = var.container_memory_reservation
  container_cpu                = var.container_cpu
  log_configuration = {
    logDriver = "awslogs"
    options = {
      awslogs-group         = module.log_group_label.id
      awslogs-region        = var.region,
      awslogs-stream-prefix = "bomber"
    }
    secretOptions = null
  }
}

resource "aws_ecs_task_definition" "default" {
  family                   = module.base_label.id
  task_role_arn            = aws_iam_role.ecs_task.arn
  execution_role_arn       = aws_iam_role.ecs_exec.arn
  container_definitions    = module.container_definition.json
  cpu                      = 256
  memory                   = 512
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  tags                     = module.base_label.tags
}

## IAM ROLES
#############

data "aws_iam_policy_document" "ecs_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# Task Role
############

resource "aws_iam_role" "ecs_task" {
  name               = module.task_label.id
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
  tags               = module.task_label.tags
}

resource "aws_iam_role_policy_attachment" "ecs_task_admin" {
  role = aws_iam_role.ecs_task.name
  # NOTE: Is this a bad idea? Yeah likely... I'm open to suggestions on this one.
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Exec Role
############

resource "aws_iam_role" "ecs_exec" {
  name               = module.exec_label.id
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
  tags               = module.exec_label.tags
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# CloudWatch Role
##################

data "aws_iam_policy_document" "events_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_events" {
  name               = module.cloudwatch_label.id
  assume_role_policy = data.aws_iam_policy_document.events_assume.json
  tags               = module.cloudwatch_label.tags
}

resource "aws_iam_role_policy_attachment" "ecs_events" {
  role       = aws_iam_role.ecs_events.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceEventsRole"
}
