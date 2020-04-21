## GENERAL
###########

variable "stage" {
  default     = "nuke"
  type        = string
  description = "The environment that this infrastrcuture is being deployed to e.g. dev, stage, or prod"
}

variable "namespace" {
  type        = string
  description = "Namespace, which could be your organization name or abbreviation, e.g. 'eg' or 'cp'"
}

variable "name" {
  default     = "bomber"
  type        = string
  description = "Solution name, e.g. 'app' or 'jenkins'"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Additional tags (e.g. `map('BusinessUnit','XYZ')`"
}

variable "region" {
  default     = "us-east-1"
  type        = string
  description = "The AWS Region to deploy these resources to."
}

variable "schedule_expression" {
  default     = "rate(24 hours)"
  type        = string
  description = "The expression to determine the schedule on which to invoke the bomber. Useful information @ https://docs.aws.amazon.com/AmazonCloudWatch/latest/events/ScheduledEvents.html."
}

variable "log_retention_in_days" {
  default     = 30
  type        = number
  description = "The number of days to retain the bomber task logs."
}

## NETWORK
###########

variable "availability_zones" {
  default     = ["us-east-1a"]
  type        = list(string)
  description = "List of Availability Zones where subnets will be created."
}

variable "vpc_cidr_block" {
  default     = "10.0.0.0/16"
  type        = string
  description = "The CIDR block used for the VPC network."
}

variable "nat_gateway_enabled" {
  default     = true
  type        = bool
  description = "Whether to enable NAT Gateways. If false, then the application uses NAT Instances, which are much cheaper."
}

## ECS
#######

variable "command" {
  default     = ["cloud-nuke", "aws", "--dry-run"]
  type        = list(string)
  description = "The CMD to execute on the ECS container. Override this to actually execute the nuke."
}

variable "container_memory" {
  default     = 512
  type        = number
  description = "The container's memory for the bomber task."
}

variable "container_memory_reservation" {
  default     = 512
  type        = number
  description = "The container's memory reservation for the bomber task."
}

variable "container_cpu" {
  default     = 256
  type        = number
  description = "The container's CPU for the bomber task."
}
