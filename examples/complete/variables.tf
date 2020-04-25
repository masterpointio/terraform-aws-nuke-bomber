variable "namespace" {
  default     = "mp"
  type        = string
  description = "Namespace, which could be your organization name or abbreviation, e.g. 'eg' or 'cp'"
}

variable "region" {
  default     = "us-east-1"
  type        = string
  description = "The AWS Region to deploy these resources to."
}

variable "availability_zones" {
  default     = ["us-east-1a"]
  type        = list(string)
  description = "List of Availability Zones where subnets will be created."
}
