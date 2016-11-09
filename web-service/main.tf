/**
 * The web-service is similar to the `service` module, but the
 * it provides a __public__ ELB instead.
 *
 * Usage:
 *
 *      module "auth_service" {
 *        source    = "github.com/segmentio/stack/service"
 *        name      = "auth-service"
 *        image     = "auth-service"
 *        cluster   = "default"
 *      }
 *
 */

/**
 * Required Variables.
 */

variable "environment" {
  description = "Environment tag, e.g prod"
}

variable "vpc_id" {
  description = "The VPC ID to use"
}

variable "image" {
  description = "The docker image name, e.g nginx"
}

variable "image_version" {
  description = "The docker image version, e.g 1.0"
}

variable "name" {
  description = "The service name, if empty the service name is defaulted to the image name"
  default     = ""
}

variable "subnet_ids" {
  description = "Comma separated list of subnet IDs that will be passed to the ELB module"
}

variable "security_groups" {
  description = "Comma separated list of security group IDs that will be passed to the ELB module"
}

variable "host_port" {
  description = "The container host port"
  default     = 0
}

variable "cluster" {
  description = "The cluster name or ARN"
}

variable "log_bucket" {
  description = "The S3 bucket ID to use for the ELB"
}

variable "iam_role" {
  description = "IAM Role ARN to use"
}

variable "external_dns_name" {
  description = "The subdomain under which the ELB is exposed externally, defaults to the task name"
  default     = ""
}

variable "internal_dns_name" {
  description = "The subdomain under which the ELB is exposed internally, defaults to the task name"
  default     = ""
}

variable "internal_zone_id" {
  description = "The zone ID to create the record in"
}

/**
 * Options.
 */

variable "healthcheck" {
  description = "Path to a healthcheck endpoint"
  default     = "/health"
}

variable "container_port" {
  description = "The container port"
  default     = 8080
}

variable "command" {
  description = "The raw json of the task command"
  default     = "[]"
}

variable "env_vars" {
  description = "The raw json of the task env vars"
  default     = "[]"
}

variable "desired_count" {
  description = "The desired count"
  default     = 2
}

variable "memory" {
  description = "The number of MiB of memory to reserve for the container"
  default     = 512
}

variable "cpu" {
  description = "The number of cpu units to reserve for the container"
  default     = 512
}

/**
 * Resources.
 */

resource "aws_ecs_service" "main" {
  name            = "${module.task.name}"
  cluster         = "${var.cluster}"
  task_definition = "${module.task.arn}"
  desired_count   = "${var.desired_count}"
  iam_role        = "${var.iam_role}"

  load_balancer {
    target_group_arn  = "${module.elb.tg_arn}"
    container_name    = "${module.task.name}"
    container_port    = "${var.container_port}"
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes = ["task_definition"]
  }
}

module "task" {
  source = "../task"

  name          = "${coalesce(var.name, replace(var.image, "/", "-"))}"
  image         = "${var.image}"
  image_version = "${var.image_version}"
  command       = "${var.command}"
  env_vars      = "${var.env_vars}"
  memory        = "${var.memory}"
  cpu           = "${var.cpu}"

  ports = <<EOF
  [
    {
      "containerPort": ${var.container_port},
      "hostPort": ${var.host_port}
    }
  ]
EOF
}

module "elb" {
  source = "./elb"

  name                = "${module.task.name}"
  vpc_id              = "${var.vpc_id}"
  port                = "${var.host_port}"
  environment         = "${var.environment}"
  subnet_ids          = "${var.subnet_ids}"
  external_dns_name   = "${coalesce(var.external_dns_name, module.task.name)}"
  internal_dns_name   = "${coalesce(var.internal_dns_name, module.task.name)}"
  healthcheck         = "${var.healthcheck}"
  internal_zone_id    = "${var.internal_zone_id}"
  security_groups     = "${var.security_groups}"
  log_bucket          = "${var.log_bucket}"
}

/**
 * Outputs.
 */


// The DNS name of the ELB
output "dns" {
  value = "${module.elb.dns}"
}

// The zone id of the ELB
output "zone_id" {
  value = "${module.elb.zone_id}"
}

// FQDN built using the zone domain and name (external)
output "external_fqdn" {
  value = "${module.elb.external_fqdn}"
}
