# ==============================================================================
# STANDALONE TASK DEFINITIONS (RunTask, scheduled tasks, one-off jobs)
# ==============================================================================

# CloudWatch Log Groups for standalone task definitions
resource "aws_cloudwatch_log_group" "standalone_td" {
  for_each = { for k, v in var.task_definitions : k => v if v.create_log_group }

  name              = local.standalone_td_log_group_names[each.key]
  retention_in_days = each.value.log_group_retention_in_days
  kms_key_id        = each.value.log_group_kms_key_id

  tags = merge(
    local.tags_common,
    each.value.log_group_tags,
    each.value.tags,
    {
      Name     = local.standalone_td_log_group_names[each.key]
      TaskName = local.standalone_td_names[each.key]
    }
  )
}

# Standalone Task Definitions
resource "aws_ecs_task_definition" "standalone" {
  for_each = var.task_definitions

  family                   = local.standalone_td_names[each.key]
  cpu                      = each.value.cpu
  memory                   = each.value.memory
  network_mode             = each.value.network_mode
  requires_compatibilities = each.value.requires_compatibilities
  pid_mode                 = each.value.pid_mode
  ipc_mode                 = each.value.ipc_mode
  skip_destroy             = each.value.skip_destroy

  task_role_arn      = each.value.task_role_arn
  execution_role_arn = coalesce(each.value.execution_role_arn, try(aws_iam_role.task_exec[0].arn, null))

  container_definitions = jsonencode(local.standalone_container_definitions[each.key])

  dynamic "runtime_platform" {
    for_each = each.value.runtime_platform != null ? [each.value.runtime_platform] : []
    content {
      operating_system_family = runtime_platform.value.operating_system_family
      cpu_architecture        = runtime_platform.value.cpu_architecture
    }
  }

  dynamic "ephemeral_storage" {
    for_each = each.value.ephemeral_storage != null ? [each.value.ephemeral_storage] : []
    content {
      size_in_gib = ephemeral_storage.value.size_in_gib
    }
  }

  dynamic "proxy_configuration" {
    for_each = each.value.proxy_configuration != null ? [each.value.proxy_configuration] : []
    content {
      type           = proxy_configuration.value.type
      container_name = proxy_configuration.value.container_name
      properties     = proxy_configuration.value.properties
    }
  }

  dynamic "volume" {
    for_each = each.value.volumes
    content {
      name      = volume.value.name
      host_path = volume.value.host_path

      dynamic "docker_volume_configuration" {
        for_each = volume.value.docker_volume_configuration != null ? [volume.value.docker_volume_configuration] : []
        content {
          scope         = docker_volume_configuration.value.scope
          autoprovision = docker_volume_configuration.value.autoprovision
          driver        = docker_volume_configuration.value.driver
          driver_opts   = docker_volume_configuration.value.driver_opts
          labels        = docker_volume_configuration.value.labels
        }
      }

      dynamic "efs_volume_configuration" {
        for_each = volume.value.efs_volume_configuration != null ? [volume.value.efs_volume_configuration] : []
        content {
          file_system_id          = efs_volume_configuration.value.file_system_id
          root_directory          = efs_volume_configuration.value.root_directory
          transit_encryption      = efs_volume_configuration.value.transit_encryption
          transit_encryption_port = efs_volume_configuration.value.transit_encryption_port

          dynamic "authorization_config" {
            for_each = efs_volume_configuration.value.authorization_config != null ? [efs_volume_configuration.value.authorization_config] : []
            content {
              access_point_id = authorization_config.value.access_point_id
              iam             = authorization_config.value.iam
            }
          }
        }
      }
    }
  }

  tags = merge(
    local.tags_common,
    each.value.tags,
    {
      Name = local.standalone_td_names[each.key]
    }
  )

  depends_on = [
    aws_cloudwatch_log_group.standalone_td,
    aws_iam_role_policy_attachment.task_exec_additional,
    aws_iam_role_policy.task_exec,
  ]

  lifecycle {
    create_before_destroy = true
  }
}
