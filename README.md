[![Masterpoint Logo](https://i.imgur.com/RDLnuQO.png)](https://masterpoint.io)

# terraform-aws-nuke-bomber

:airplane:
:bomb:
:cloud:

This terraform module deploys a VPC, ECS Cluster, and Scheduled ECS Fargate Task to repeatedly execute [`aws-nuke`](https://github.com/rebuy-de/aws-nuke), which removes all resources in the given AWS Account. This is intended for usage in "Test Accounts" where developers or CI / CD are typically deploying infrastructure that needs to be cleaned up often, otherwise it would incur unnecessary costs.

##### NOTE: As is stated multiple times on the `aws-nuke` repo, this project should similarly be used with extreme caution for obvious reasons. You should explicitly add all AWS Account IDs that you *don't* want nuked to the exclude section of your `nuke-config.yml` file and be sure to properly configure the filters in that same file to keep around any resources which you don't want removed. Always run this project in dry-run mode first (on by default) and only override the terraform `command` variable to use `--no-dry-run` once you've ensured everything is running properly. This project and its maintainers are not responsible for not following those steps.

Big shout out to the following projects which this project uses/depends on!  
1. [rebuy-de/aws-nuke](https://github.com/rebuy-de/aws-nuke)  
1. [cloudposse/terraform-null-label](https://github.com/cloudposse/terraform-null-label)  
1. [cloudposse/terraform-aws-vpc](https://github.com/cloudposse/terraform-aws-vpc)  
1. [cloudposse/terraform-aws-dynamic-subnets](https://github.com/cloudposse/terraform-aws-dynamic-subnets )  
1. [cloudposse/terraform-aws-ecs-container-definition](https://github.com/cloudposse/terraform-aws-ecs-container-definition)

## Usage

First, deploy the module:

```hcl
provider "aws" {
  region = "us-east-1"
}

module "nuke_bomber" {
  source    = "git::https://github.com/masterpointio/terraform-aws-nuke-bomber.git?ref=tags/0.1.0"
  namespace = var.namespace

  # NOTE: 5 minutes is way too often. This is just for testing / example purposes.
  # Change this once you're not running drills!
  schedule_expression = "rate(5 minutes)"
}
```

Next, to get the ECS Task running, you need to do the following:

1. Clone this repo and change into this directory:
    - `git clone git@github.com:masterpointio/terraform-aws-nuke-bomber.git && cd terraform-aws-nuke-bomber`  
1. Copy nuke-config example:
    - `cp nuke-config.yml.example nuke-config.yml`  
1. Replace your `nuke-config.yml` `TODO_` fields with your Account ID, Region, and Production Account ID(s).  
1. Check over the config. Make sure to exclude or filter out anything you don't want removed from your account!  
1. From your terraform project direct, grab the ECR Repo URL from the terraform output:
    - `export ECR_REPO=$(terraform output ecr_repo_url)`  
1. Make sure you've got an ECR Push token via:
    - `eval $(aws ecr get-login --region us-east-1 --no-include-email)`  
1. Build, tag, and push the Docker image:
    - `make`  
1. Check out your logs in CloudWatch to watch the bomb drop!

Noticed that nothing got deleted even though your bomber should've nuked the account? That was just a drill... update your nuke\_bomber module with the following and `terraform apply` the change to fire for effect:
```hcl
module "nuke_bomber" {
  source    = "git::https://github.com/masterpointio/terraform-aws-nuke-bomber.git?ref=tags/0.1.0"
  namespace = var.namespace
  command   = ["-c", "/home/aws-nuke/nuke-config.yml", "--force", "--force-sleep", "3", "--no-dry-run"]
  schedule_expression = "rate(48 hours)"
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 0.12 |
| aws | ~> 2.0 |

## Providers

| Name | Version |
|------|---------|
| aws | ~> 2.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| attributes | Additional attributes (e.g. `1`) | `list(string)` | `[]` | no |
| availability\_zones | List of Availability Zones where subnets will be created. | `list(string)` | n/a | yes |
| command | The CMD to execute on the ECS container. Override this to actually execute the nuke. | `list(string)` | <pre>[<br>  "-c",<br>  "/home/aws-nuke/nuke-config.yml",<br>  "--force",<br>  "--force-sleep",<br>  "3"<br>]</pre> | no |
| container\_cpu | The container's CPU for the bomber task. | `number` | `256` | no |
| container\_memory | The container's memory for the bomber task. | `number` | `512` | no |
| container\_memory\_reservation | The container's memory reservation for the bomber task. | `number` | `512` | no |
| delimiter | Delimiter to be used between `namespace`, `stage`, `name` and `attributes` | `string` | `"-"` | no |
| environment | Environment, e.g. 'prod', 'staging', 'dev', 'pre-prod', 'UAT' | `string` | `""` | no |
| log\_retention\_in\_days | The number of days to retain the bomber task logs. | `number` | `30` | no |
| name | Solution name, e.g. 'app' or 'jenkins' | `string` | `"bomber"` | no |
| namespace | Namespace, which could be your organization name or abbreviation, e.g. 'eg' or 'cp' | `string` | n/a | yes |
| nat\_gateway\_enabled | Whether to enable NAT Gateways. If false, then the application uses NAT Instances, which are much cheaper. | `bool` | `false` | no |
| region | The AWS Region to deploy these resources to. | `string` | n/a | yes |
| schedule\_expression | The expression to determine the schedule on which to invoke the bomber. Useful information @ https://docs.aws.amazon.com/AmazonCloudWatch/latest/events/ScheduledEvents.html. | `string` | `"rate(24 hours)"` | no |
| stage | The environment that this infrastrcuture is being deployed to e.g. dev, stage, or prod | `string` | `"nuke"` | no |
| tags | Additional tags (e.g. `map('BusinessUnit','XYZ')` | `map(string)` | `{}` | no |
| vpc\_cidr\_block | The CIDR block used for the VPC network. | `string` | `"10.0.0.0/16"` | no |

## Outputs

| Name | Description |
|------|-------------|
| ecr\_repo\_url | The URL of the ECR Repo to push your docker image to. |

