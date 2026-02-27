# ==============================================================================
# CLUSTER OUTPUTS
# ==============================================================================

output "cluster_id" {
  description = "ID of the ECS cluster"
  value       = aws_ecs_cluster.this.id
}

output "cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.this.arn
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.this.name
}

# ==============================================================================
# CLOUDWATCH LOG GROUP OUTPUTS
# ==============================================================================

output "cluster_log_group_name" {
  description = "Name of the cluster CloudWatch log group"
  value       = try(aws_cloudwatch_log_group.cluster[0].name, null)
}

output "cluster_log_group_arn" {
  description = "ARN of the cluster CloudWatch log group"
  value       = try(aws_cloudwatch_log_group.cluster[0].arn, null)
}

# ==============================================================================
# CAPACITY PROVIDER OUTPUTS
# ==============================================================================

output "cluster_capacity_providers" {
  description = "Map of cluster capacity providers attributes"
  value       = aws_ecs_cluster_capacity_providers.this
}

output "autoscaling_capacity_providers" {
  description = "Map of autoscaling capacity providers created and their attributes"
  value       = aws_ecs_capacity_provider.this
}

# ==============================================================================
# TASK EXECUTION ROLE OUTPUTS
# ==============================================================================

output "task_exec_iam_role_name" {
  description = "Name of the task execution IAM role"
  value       = try(aws_iam_role.task_exec[0].name, null)
}

output "task_exec_iam_role_arn" {
  description = "ARN of the task execution IAM role"
  value       = try(aws_iam_role.task_exec[0].arn, null)
}

output "task_exec_iam_role_unique_id" {
  description = "Unique ID of the task execution IAM role"
  value       = try(aws_iam_role.task_exec[0].unique_id, null)
}

# ==============================================================================
# SERVICE OUTPUTS
# ==============================================================================

output "services" {
  description = "Map of ECS service attributes"
  value = merge(
    { for k, v in aws_ecs_service.this : k => {
      id                  = v.id
      name                = v.name
      cluster             = v.cluster
      desired_count       = v.desired_count
      launch_type         = v.launch_type
      platform_version    = v.platform_version
      scheduling_strategy = v.scheduling_strategy
      tags_all            = v.tags_all
    } },
    { for k, v in aws_ecs_service.ignore_task_definition : k => {
      id                  = v.id
      name                = v.name
      cluster             = v.cluster
      desired_count       = v.desired_count
      launch_type         = v.launch_type
      platform_version    = v.platform_version
      scheduling_strategy = v.scheduling_strategy
      tags_all            = v.tags_all
    } }
  )
}

# ==============================================================================
# TASK DEFINITION OUTPUTS
# ==============================================================================

output "task_definitions" {
  description = "Map of service task definition attributes"
  value = {
    for k, v in aws_ecs_task_definition.this : k => {
      arn                  = v.arn
      arn_without_revision = v.arn_without_revision
      family               = v.family
      revision             = v.revision
    }
  }
}

# ==============================================================================
# STANDALONE TASK DEFINITION OUTPUTS
# ==============================================================================

output "standalone_task_definitions" {
  description = "Map of standalone task definition attributes (for RunTask, scheduled tasks)"
  value = {
    for k, v in aws_ecs_task_definition.standalone : k => {
      arn                  = v.arn
      arn_without_revision = v.arn_without_revision
      family               = v.family
      revision             = v.revision
    }
  }
}

output "standalone_task_definition_log_groups" {
  description = "Map of standalone task definition CloudWatch log group attributes"
  value = {
    for k, v in aws_cloudwatch_log_group.standalone_td : k => {
      name = v.name
      arn  = v.arn
    }
  }
}

# ==============================================================================
# SERVICE LOG GROUP OUTPUTS
# ==============================================================================

output "service_log_groups" {
  description = "Map of service CloudWatch log group attributes"
  value = {
    for k, v in aws_cloudwatch_log_group.service : k => {
      name = v.name
      arn  = v.arn
    }
  }
}

# ==============================================================================
# AUTOSCALING OUTPUTS
# ==============================================================================

output "autoscaling_targets" {
  description = "Map of autoscaling target attributes"
  value = {
    for k, v in aws_appautoscaling_target.this : k => {
      min_capacity = v.min_capacity
      max_capacity = v.max_capacity
      resource_id  = v.resource_id
    }
  }
}

output "autoscaling_policies" {
  description = "Map of autoscaling policy attributes"
  value = {
    for k, v in aws_appautoscaling_policy.this : k => {
      name        = v.name
      policy_type = v.policy_type
      arn         = v.arn
    }
  }
}
