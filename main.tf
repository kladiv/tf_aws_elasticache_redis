data "aws_vpc" "vpc" {
  id = var.vpc_id
}

locals {
  parameter_group_family = substr(var.redis_version, 0,1) < 6 ?  "redis${replace(var.redis_version, "/\\.[\\d]+$/", "")}": "redis${replace(var.redis_version, "/\\.[\\d]+$/", "")}.x"
  name = coalesce(var.replication_group_name, "${var.name}-${var.env}")
}

resource "random_id" "salt" {
  byte_length = 8
  keepers = {
    redis_version = var.redis_version
  }
}

resource "aws_elasticache_replication_group" "this" {
  replication_group_id       = coalesce(var.replication_group_name, format("%.20s", local.name))
  description                = "Redis ElastiCache replication group for ${local.name}"
  num_cache_clusters         = var.redis_clusters
  node_type                  = var.redis_node_type
  automatic_failover_enabled = var.redis_failover
  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  availability_zones         = var.availability_zones
  multi_az_enabled           = var.multi_az_enabled
  engine                     = "redis"
  at_rest_encryption_enabled = var.at_rest_encryption_enabled
  kms_key_id                 = var.kms_key_id
  transit_encryption_enabled = var.transit_encryption_enabled
  auth_token                 = var.transit_encryption_enabled ? var.auth_token : null
  engine_version             = var.redis_version
  port                       = var.redis_port
  parameter_group_name       = aws_elasticache_parameter_group.this.id
  subnet_group_name          = var.create_subnet_group ? aws_elasticache_subnet_group.this[0].id : var.subnet_group_id
  security_group_names       = var.security_group_names
  security_group_ids         = [aws_security_group.this.id]
  snapshot_arns              = var.snapshot_arns
  snapshot_name              = var.snapshot_name
  apply_immediately          = var.apply_immediately
  maintenance_window         = var.redis_maintenance_window
  notification_topic_arn     = var.notification_topic_arn
  snapshot_window            = var.redis_snapshot_window
  snapshot_retention_limit   = var.redis_snapshot_retention_limit
  
  tags = merge(
    { "Name" = coalesce(var.parameter_group_name, format("tf-elasticache-%s", local.name)) },
    var.subnet_group_tags,
  )
}

resource "aws_elasticache_parameter_group" "this" {
  name        = coalesce(var.subnet_group_name, replace(format("%.255s", lower(replace("tf-redis-${local.name}-${random_id.salt.hex}", "_", "-"))), "/\\s/", "-"))
  description = "Redis ElastiCache parameter group for ${local.name}"

  # Strip the patch version from redis_version var
  family = local.parameter_group_family
  dynamic "parameter" {
    for_each = var.redis_parameters
    content {
      name  = parameter.value.name
      value = parameter.value.value
    }
  }

  tags = merge(
    { "Name" = coalesce(var.parameter_group_name, lower(replace("tf-redis-${local.name}-${random_id.salt.hex}", "_", "-"))) },
    var.subnet_group_tags,
  )
}

resource "aws_elasticache_subnet_group" "this" {
  count = var.create_subnet_group && length(var.subnets) > 0 ? 1 : 0
  
  name       = coalesce(var.subnet_group_name, replace(format("%.255s", lower(replace("tf-redis-${local.name}", "_", "-"))), "/\\s/", "-"))
  subnet_ids = var.subnets

  tags = merge(
    { "Name" = coalesce(var.subnet_group_name, lower(replace("tf-redis-${local.name}", "_", "-"))) },
    var.subnet_group_tags,
  )
}