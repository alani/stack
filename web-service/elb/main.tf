/**
 * The ELB module creates an ELB, security group
 * a route53 record and a service healthcheck.
 * It is used by the service module.
 */

variable "name" {
  description = "ELB name, e.g cdn"
}

variable "vpc_id" {
  description = "The VPC ID to use"
}

variable "subnet_ids" {
  description = "Comma separated list of subnet IDs"
}

variable "environment" {
  description = "Environment tag, e.g prod"
}

variable "port" {
  description = "Instance port"
}

variable "security_groups" {
  description = "Comma separated list of security group IDs"
}

variable "healthcheck" {
  description = "Healthcheck path"
}

variable "log_bucket" {
  description = "S3 bucket name to write ELB logs into"
}

variable "external_dns_name" {
  description = "The subdomain under which the ELB is exposed externally, defaults to the task name"
}

variable "internal_dns_name" {
  description = "The subdomain under which the ELB is exposed internally, defaults to the task name"
}


variable "internal_zone_id" {
  description = "The zone ID to create the record in"
}

/**
 * Resources.
 */

resource "aws_route53_zone" "main" {
  name    = "${var.external_dns_name}"
}

resource "aws_alb" "main" {
  name            = "${var.name}-alb"
  internal        = false
  security_groups = ["${split(",",var.security_groups)}"]
  subnets         = ["${split(",", var.subnet_ids)}"]

  access_logs {
    bucket = "${var.log_bucket}"
  }

  tags {
    Name        = "${var.name}-balancer"
    Service     = "${var.name}"
    Environment = "${var.environment}"
  }
}

resource "aws_alb_target_group" "main_http" {
  name     = "${var.name}-http-alb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${var.vpc_id}"

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "${var.healthcheck}"
  }

  tags {
    Name        = "${var.name}-http-alb-tg"
    Service     = "${var.name}"
    Environment = "${var.environment}"
  }
}

resource "aws_alb_listener" "main_http" {
   load_balancer_arn = "${aws_alb.main.arn}"
   port = "80"
   protocol = "HTTP"

   default_action {
     target_group_arn = "${aws_alb_target_group.main_http.arn}"
     type = "forward"
   }
}

resource "aws_route53_record" "external" {
  zone_id = "${aws_route53_zone.main.zone_id}"
  name    = "${var.external_dns_name}"
  type    = "A"

  alias {
    zone_id                = "${aws_alb.main.zone_id}"
    name                   = "${aws_alb.main.dns_name}"
    evaluate_target_health = false
  }

  # This is required in order to ensure A record is removed before 
  # root DNS zone is removed
  depends_on = ["aws_route53_zone.main"]
}

/**
 * Outputs.
 */

// The ELB ID.
output "tg_arn" {
  value = "${aws_alb_target_group.main_http.arn}"
}

// The ELB dns_name.
output "dns" {
  value = "${aws_alb.main.dns_name}"
}

// FQDN built using the zone domain and name (external)
output "external_fqdn" {
  value = "${aws_route53_record.external.fqdn}"
}

// The zone id of the ELB
output "zone_id" {
  value = "${aws_alb.main.zone_id}"
}
