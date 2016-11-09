variable "name" {
    type = "string"
}

variable "environment" {
    type = "string"
}

variable "email_address" {
    type = "string"
}

variable "display_name" {
    type = "string"
}

variable "protocol" {
    default = "email"
    type    = "string"
}

data "template_file" "cloudformation_sns_stack" {
    template = "${file("${path.module}/files/email-sns-stack.json.tpl")}"

    vars {
        display_name  = "${var.display_name}"
        email_address = "${var.email_address}"
        protocol      = "${var.protocol}"
    }
}

resource "aws_cloudformation_stack" "sns-topic" {
    name = "${var.name}-sns-topic"
    template_body = "${data.template_file.cloudformation_sns_stack.rendered}"

    tags {
        Name        = "${var.name}-sns-topic"
        Environment = "${var.environment}"
    }
}

output "arn" {
    value = "${aws_cloudformation_stack.sns-topic.outputs.ARN}"
}