#
# Variables
#

variable "name" {
  description = "The name will be used to prefix and tag the resources, e.g mydb"
}

variable "environment" {
  description = "The environment tag, e.g prod"
}

variable "vpc_id" {
  description = "The VPC ID to use"
}

variable "zone_id" {
  description = "The Route53 Zone ID where the DNS record will be created"
}

variable "security_groups" {
  description = "Comma separated list of security groups"
}

variable "subnet_ids" {
  description = "A list of subnet IDs"
  type = "list"
}

variable "availability_zones" {
  description = "A list of availability zones"
  type = "list"
}

variable "database_name" {
  description = "The database name"
}

variable "allocated_storage" {
  description = "The amount of storage allocated to the DB in GB, e.g 100"
  default     = 100
}

variable "engine" {
  description = "The database engine"
  default    = "postgres"
}

variable "engine_version" {
  description = "The database engine version"
  default    = "9.5.4"
}

variable "username" {
  description = "The username"
}

variable "password" {
  description = "The  password"
}

variable "instance_class" {
  description = "The type of instances that the RDS cluster will be running on"
  default     = "db.t2.small"
}

variable "backup_window" {
  description = "The time window on which backups will be made (HH:mm-HH:mm)"
  default     = "07:00-09:00"
}

variable "backup_retention_period" {
  description = "The backup retention period"
  default     = 5
}

variable "maintenance_window" {
  description = "The time window on which maintance will be made (Day:HH:mm-Day:HH:mm)"
  default     = "Sun:10:00-Sun:12:00"
}

variable "publicly_accessible" {
  description = "When set to true the RDS instance can be reached from outside the VPC"
  default     = false
}

variable "dns_name" {
  description = "Route53 record name for the RDS database, defaults to the database name if not set"
  default     = ""
}

variable "port" {
  description = "The port at which the database listens for incoming connections"
  default     = 5432
}

variable "parameter_group_name" {
  description = "The name of the DB parameter group"
  default     = "default.postgres9.5"
}

variable "multi_az" {
  description = "Is this a multi-az instance"
  default     = true
}

variable "storage_type" {
  description = "The storage type of the RDS instance"
  default     = "gp2"
}

variable "storage_encrypted" {
  description = "Is the RDS instance storage encrypted"
  default     = false
}

variable "skip_final_snapshot" {
  description = "Is the RDS instance skipping the final snapshot upon deletion"
  default     = false
}

variable "alarm_actions" {
  type = "list"
  default     = []
}

variable "alarm_cpu_threshold" {
  default = "75"
}

variable "alarm_disk_queue_threshold" {
  default = "10"
}

variable "alarm_free_disk_threshold" {
  # 10GB
  default = "10000000000"
}

variable "alarm_free_memory_threshold" {
  # 128MB
  default = "128000000"
}

#
# RDS Instance Resources
#

resource "aws_security_group" "main" {
  name        = "${var.name}-rds-instance"
  description = "Allows traffic to rds from other security groups"
  vpc_id      = "${var.vpc_id}"

  ingress {
    from_port       = "${var.port}"
    to_port         = "${var.port}"
    protocol        = "TCP"
    security_groups = ["${var.security_groups}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name        = "RDS instance (${var.name})"
    Environment = "${var.environment}"
  }
}

resource "aws_db_subnet_group" "main" {
  name        = "${var.name}"
  description = "RDS instance subnet group"
  subnet_ids  = ["${var.subnet_ids}"]
}

resource "aws_db_instance" "main" {
  identifier                = "${var.name}"
  allocated_storage         = "${var.allocated_storage}"
  engine                    = "${var.engine}"
  engine_version            = "${var.engine_version}"
  port                      = "${var.port}"
  instance_class            = "${var.instance_class}"
  name                      = "${var.database_name}"
  username                  = "${var.username}"
  password                  = "${var.password}"
  vpc_security_group_ids    = ["${aws_security_group.main.id}"]
  db_subnet_group_name      = "${aws_db_subnet_group.main.id}"
  parameter_group_name      = "${var.parameter_group_name}"
  multi_az                  = "${var.multi_az}"
  storage_type              = "${var.storage_type}"
  backup_retention_period   = "${var.backup_retention_period}"
  backup_window             = "${var.backup_window}"
  maintenance_window        = "${var.maintenance_window}"
  storage_encrypted         = "${var.storage_encrypted}"
  skip_final_snapshot       = "${var.skip_final_snapshot}"
  final_snapshot_identifier = "${var.name}-final-snapshot"

  tags {
    Name        = "${var.name}"
    Environment = "${var.environment}"
  }
}

resource "aws_route53_record" "main" {
  zone_id = "${var.zone_id}"
  name    = "${coalesce(var.dns_name, var.name)}"
  type    = "CNAME"
  ttl     = 300
  records = ["${aws_db_instance.main.address}"]
}

#
# CloudWatch resources
#

resource "aws_cloudwatch_metric_alarm" "database_cpu" {
  alarm_name          = "${var.name}-PostgreSQL-DatabaseServerCPUUtilization-High"
  alarm_description   = "Alert if Database Server CPU Utilization > 75% for 5 minutes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "${var.alarm_cpu_threshold}"

  dimensions {
    DBInstanceIdentifier = "${aws_db_instance.main.id}"
  }

  alarm_actions = ["${var.alarm_actions}"]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudwatch_metric_alarm" "database_disk_queue" {
  alarm_name          = "${var.name}-PostgreSQL-DatabaseServerDiskQueueDepth-High"
  alarm_description   = "Alert if Database Server Queue Depth > 10 for 1 minute"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "DiskQueueDepth"
  namespace           = "AWS/RDS"
  period              = "60"
  statistic           = "Average"
  threshold           = "${var.alarm_disk_queue_threshold}"

  dimensions {
    DBInstanceIdentifier = "${aws_db_instance.main.id}"
  }

  alarm_actions = ["${var.alarm_actions}"]

  lifecycle {
    create_before_destroy = true
  }

  # This is required to make cloudwatch alarms creation sequential, AWS doesn't
  # support modifying alarms concurrently.
  depends_on = ["aws_cloudwatch_metric_alarm.database_cpu"]
}

resource "aws_cloudwatch_metric_alarm" "database_disk_free" {
  alarm_name          = "${var.name}-PostgreSQL-DatabaseServerFreeStorageSpace-Low"
  alarm_description   = "Alert if Database Server Free Storage Space < 10GB for 1 minute"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = "60"
  statistic           = "Average"
  threshold           = "${var.alarm_free_disk_threshold}"

  dimensions {
    DBInstanceIdentifier = "${aws_db_instance.main.id}"
  }

  alarm_actions = ["${var.alarm_actions}"]

  lifecycle {
    create_before_destroy = true
  }

  # This is required to make cloudwatch alarms creation sequential, AWS doesn't
  # support modifying alarms concurrently.
  depends_on = ["aws_cloudwatch_metric_alarm.database_disk_queue"]
}

#// http://stackoverflow.com/questions/15332158/amazon-rds-running-out-of-freeable-memory-should-i-be-worried

resource "aws_cloudwatch_metric_alarm" "database_memory_free" {
  alarm_name          = "${var.name}-PostgreSQL-DatabaseServerFreeableMemory-Low"
  alarm_description   = "Alert if Database Server Freeable Memory < 128MB for 1 minute"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "FreeableMemory"
  namespace           = "AWS/RDS"
  period              = "60"
  statistic           = "Average"
  threshold           = "${var.alarm_free_memory_threshold}"

  dimensions {
    DBInstanceIdentifier = "${aws_db_instance.main.id}"
  }

  alarm_actions = ["${var.alarm_actions}"]

  lifecycle {
    create_before_destroy = true
  }

  # This is required to make cloudwatch alarms creation sequential, AWS doesn't
  # support modifying alarms concurrently.
  depends_on = ["aws_cloudwatch_metric_alarm.database_disk_free"]
}

#
# RDS Instance Outputs
#

output "id" {
  value = "${aws_db_instance.main.id}"
}

output "endpoint" {
  value = "${aws_db_instance.main.endpoint}"
}

output "address" {
  value = "${aws_db_instance.main.address}"
}

output "fqdn" {
  value = "${aws_route53_record.main.fqdn}"
}

output "port" {
  value = "${aws_db_instance.main.port}"
}
