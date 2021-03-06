/**
 * This module is used to set configuration defaults for the AWS infrastructure.
 * It doesn't provide much value when used on its own because terraform makes it
 * hard to do dynamic generations of things like subnets, for now it's used as
 * a helper module for the stack.
 *
 * Usage:
 *
 *     module "defaults" {
 *       source = "github.com/segmentio/stack/defaults"
 *       region = "us-east-1"
 *       cidr   = "10.0.0.0/16"
 *     }
 *
 */

variable "region" {
  description = "The AWS region"
}

variable "cidr" {
  description = "The CIDR block to provision for the VPC"
}

variable "default_ecs_ami" {
  default = {
    us-east-1      = "ami-1924770e"
    us-east-2      = "ami-bd3e64d8"
    us-west-1      = "ami-7f004b1f"
    us-west-2      = "ami-56ed4936"
    eu-west-1      = "ami-c8337dbb"
    eu-central-1   = "ami-dd12ebb2"
    ap-northeast-1 = "ami-c8b016a9"
    ap-southeast-1 = "ami-6d22840e"
    ap-southeast-2 = "ami-73407d10"
  }
}

# http://docs.aws.amazon.com/ElasticLoadBalancing/latest/DeveloperGuide/enable-access-logs.html#attach-bucket-policy
variable "default_log_account_ids" {
  default = {
    us-east-1      = "127311923021"
    us-east-2      = "033677994240"
    us-west-2      = "797873946194"
    us-west-1      = "027434742980"
    eu-west-1      = "156460612806"
    eu-central-1   = "054676820928"
    ap-southeast-1 = "114774131450"
    ap-northeast-1 = "582318560864"
    ap-southeast-2 = "783225319266"
    ap-northeast-2 = "600734575887"
    sa-east-1      = "507241528517"
    us-gov-west-1  = "048591011584"
    cn-north-1     = "638102146993"
  }
}

// http://docs.aws.amazon.com/Route53/latest/DeveloperGuide/hosted-zones-private.html
// http://serverfault.com/questions/662365/how-to-set-up-an-internal-domain-with-route53-on-aws
output "domain_name_servers" {
  value = "${cidrhost(var.cidr, 2)},AmazonProvidedDNS"
}

output "ecs_ami" {
  value = "${lookup(var.default_ecs_ami, var.region)}"
}

output "s3_logs_account_id" {
  value = "${lookup(var.default_log_account_ids, var.region)}"
}
