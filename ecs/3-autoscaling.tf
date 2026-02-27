# ==============================================================================
# APPLICATION AUTO SCALING
# ==============================================================================

locals {
  # Flatten services that have autoscaling enabled
  autoscaling_services = {
    for k, v in var.services : k => v if v.enable_autoscaling && v.autoscaling != null
  }

  # Resolve service resource IDs for autoscaling target
  service_resource_ids = {
    for k, v in var.services : k => v.ignore_task_definition_changes ? (
      "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.ignore_task_definition[k].name}"
      ) : (
      "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.this[k].name}"
    )
  }

  # Flatten autoscaling policies
  autoscaling_policies = merge([
    for service_key, service in local.autoscaling_services : {
      for policy_key, policy in try(service.autoscaling.policies, {}) :
      "${service_key}/${policy_key}" => merge(policy, {
        service_key = service_key
        policy_key  = policy_key
      })
    }
  ]...)

  # Flatten scheduled actions
  autoscaling_scheduled_actions = merge([
    for service_key, service in local.autoscaling_services : {
      for action_key, action in try(service.autoscaling.scheduled_actions, {}) :
      "${service_key}/${action_key}" => merge(action, {
        service_key = service_key
        action_key  = action_key
      })
    }
  ]...)
}

# ==============================================================================
# AUTOSCALING TARGET
# ==============================================================================

resource "aws_appautoscaling_target" "this" {
  for_each = local.autoscaling_services

  min_capacity = each.value.autoscaling.min_capacity
  max_capacity = each.value.autoscaling.max_capacity

  resource_id        = local.service_resource_ids[each.key]
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  tags = merge(
    local.tags_common,
    each.value.tags
  )
}

# ==============================================================================
# AUTOSCALING POLICIES
# ==============================================================================

resource "aws_appautoscaling_policy" "this" {
  for_each = local.autoscaling_policies

  name               = "${local.service_names[each.value.service_key]}-${each.value.policy_key}"
  policy_type        = each.value.policy_type
  resource_id        = aws_appautoscaling_target.this[each.value.service_key].resource_id
  scalable_dimension = aws_appautoscaling_target.this[each.value.service_key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.this[each.value.service_key].service_namespace

  dynamic "target_tracking_scaling_policy_configuration" {
    for_each = each.value.target_tracking_scaling_policy_configuration != null ? [each.value.target_tracking_scaling_policy_configuration] : []
    iterator = config
    content {
      target_value       = config.value.target_value
      scale_in_cooldown  = config.value.scale_in_cooldown
      scale_out_cooldown = config.value.scale_out_cooldown

      dynamic "predefined_metric_specification" {
        for_each = config.value.predefined_metric_specification != null ? [config.value.predefined_metric_specification] : []
        content {
          predefined_metric_type = predefined_metric_specification.value.predefined_metric_type
          resource_label         = predefined_metric_specification.value.resource_label
        }
      }

      dynamic "customized_metric_specification" {
        for_each = config.value.customized_metric_specification != null ? [config.value.customized_metric_specification] : []
        content {
          dynamic "metrics" {
            for_each = try(customized_metric_specification.value.metrics, [])
            content {
              id          = metrics.value.id
              label       = metrics.value.label
              expression  = metrics.value.expression
              return_data = metrics.value.return_data

              dynamic "metric_stat" {
                for_each = metrics.value.metric_stat != null ? [metrics.value.metric_stat] : []
                content {
                  stat = metric_stat.value.stat
                  unit = metric_stat.value.unit

                  metric {
                    metric_name = metric_stat.value.metric.metric_name
                    namespace   = metric_stat.value.metric.namespace

                    dynamic "dimensions" {
                      for_each = try(metric_stat.value.metric.dimensions, [])
                      content {
                        name  = dimensions.value.name
                        value = dimensions.value.value
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}

# ==============================================================================
# AUTOSCALING SCHEDULED ACTIONS
# ==============================================================================

resource "aws_appautoscaling_scheduled_action" "this" {
  for_each = local.autoscaling_scheduled_actions

  name               = "${local.service_names[each.value.service_key]}-${each.value.action_key}"
  resource_id        = aws_appautoscaling_target.this[each.value.service_key].resource_id
  scalable_dimension = aws_appautoscaling_target.this[each.value.service_key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.this[each.value.service_key].service_namespace

  schedule   = each.value.schedule
  timezone   = each.value.timezone
  start_time = each.value.start_time
  end_time   = each.value.end_time

  scalable_target_action {
    min_capacity = each.value.min_capacity
    max_capacity = each.value.max_capacity
  }
}
