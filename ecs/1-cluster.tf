# ==============================================================================
# ECS CLUSTER
# ==============================================================================

resource "aws_ecs_cluster" "this" {
  name = local.cluster_name

  dynamic "setting" {
    for_each = var.cluster_settings
    content {
      name  = setting.value.name
      value = setting.value.value
    }
  }

  dynamic "configuration" {
    for_each = length(var.cluster_execute_command_configuration) > 0 ? [var.cluster_execute_command_configuration] : []
    content {
      execute_command_configuration {
        kms_key_id = try(configuration.value.kms_key_id, null)
        logging    = try(configuration.value.logging, "DEFAULT")

        dynamic "log_configuration" {
          for_each = try(configuration.value.log_configuration, null) != null ? [configuration.value.log_configuration] : []
          content {
            cloud_watch_encryption_enabled = try(log_configuration.value.cloud_watch_encryption_enabled, true)
            cloud_watch_log_group_name     = try(log_configuration.value.cloud_watch_log_group_name, null)
            s3_bucket_name                 = try(log_configuration.value.s3_bucket_name, null)
            s3_bucket_encryption_enabled   = try(log_configuration.value.s3_bucket_encryption_enabled, true)
            s3_key_prefix                  = try(log_configuration.value.s3_key_prefix, null)
          }
        }
      }
    }
  }

  dynamic "service_connect_defaults" {
    for_each = var.cluster_service_connect_defaults != null ? [var.cluster_service_connect_defaults] : []
    content {
      namespace = service_connect_defaults.value.namespace
    }
  }

  tags = merge(
    local.tags_common,
    {
      Name = local.cluster_name
    }
  )
}

# ==============================================================================
# CLUSTER CLOUDWATCH LOG GROUP
# ==============================================================================

resource "aws_cloudwatch_log_group" "cluster" {
  count = var.create_cloudwatch_log_group ? 1 : 0

  name              = "/ecs/${local.cluster_name}"
  retention_in_days = var.cloudwatch_log_group_retention_in_days
  kms_key_id        = var.cloudwatch_log_group_kms_key_id

  tags = merge(
    local.tags_common,
    var.cloudwatch_log_group_tags,
    {
      Name = "/ecs/${local.cluster_name}"
    }
  )
}

# ==============================================================================
# CAPACITY PROVIDERS
# ==============================================================================

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name = aws_ecs_cluster.this.name

  capacity_providers = distinct(concat(
    var.default_capacity_provider_use_fargate ? keys(var.fargate_capacity_providers) : [],
    keys(var.autoscaling_capacity_providers) != [] ? [for k, v in aws_ecs_capacity_provider.this : v.name] : []
  ))

  dynamic "default_capacity_provider_strategy" {
    for_each = var.default_capacity_provider_use_fargate ? var.fargate_capacity_providers : {}
    iterator = strategy

    content {
      capacity_provider = strategy.key
      weight            = try(strategy.value.default_capacity_provider_strategy.weight, null)
      base              = try(strategy.value.default_capacity_provider_strategy.base, null)
    }
  }

  dynamic "default_capacity_provider_strategy" {
    for_each = { for k, v in var.autoscaling_capacity_providers : k => v if v.default_capacity_provider_strategy != null }
    iterator = strategy

    content {
      capacity_provider = aws_ecs_capacity_provider.this[strategy.key].name
      weight            = try(strategy.value.default_capacity_provider_strategy.weight, null)
      base              = try(strategy.value.default_capacity_provider_strategy.base, null)
    }
  }

  depends_on = [aws_ecs_capacity_provider.this]
}

# ==============================================================================
# AUTOSCALING CAPACITY PROVIDERS (EC2)
# ==============================================================================

resource "aws_ecs_capacity_provider" "this" {
  for_each = var.autoscaling_capacity_providers

  name = "${local.cluster_name}-${each.key}"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = each.value.auto_scaling_group_arn
    managed_termination_protection = each.value.managed_termination_protection
    managed_draining               = try(each.value.managed_draining, "ENABLED")

    dynamic "managed_scaling" {
      for_each = try([each.value.managed_scaling], [])
      content {
        instance_warmup_period    = try(managed_scaling.value.instance_warmup_period, null)
        maximum_scaling_step_size = try(managed_scaling.value.maximum_scaling_step_size, null)
        minimum_scaling_step_size = try(managed_scaling.value.minimum_scaling_step_size, null)
        status                    = try(managed_scaling.value.status, "ENABLED")
        target_capacity           = try(managed_scaling.value.target_capacity, 100)
      }
    }
  }

  tags = merge(
    local.tags_common,
    try(each.value.tags, {}),
    {
      Name = "${local.cluster_name}-${each.key}"
    }
  )
}
