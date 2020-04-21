/**
 * [![Masterpoint Logo](https://i.imgur.com/RDLnuQO.png)](https://masterpoint.io)
 *
 * # terraform-aws-nuke
 *
 * TODO
 *
 * Big shout out to the folks [@cloudposse](https://github.com/cloudposse), who have awesome open source modules which this repo uses heavily!
 *
 * ## Usage
 *
 * ```hcl
 *
 * TODO
 *
 * ```
 *
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
}

resource "aws_cloudwatch_event_target" "default" {
  target_id = module.event_label.id
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
  task_role_arn            = ""
  execution_role_arn       = ""
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
