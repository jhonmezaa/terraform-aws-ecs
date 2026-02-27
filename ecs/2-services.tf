# ==============================================================================
# CLOUDWATCH LOG GROUPS (PER SERVICE)
# ==============================================================================

resource "aws_cloudwatch_log_group" "service" {
  for_each = { for k, v in var.services : k => v if v.create_log_group }

  name              = local.log_group_names[each.key]
  retention_in_days = each.value.log_group_retention_in_days
  kms_key_id        = each.value.log_group_kms_key_id

  tags = merge(
    local.tags_common,
    each.value.log_group_tags,
    each.value.tags,
    {
      Name        = local.log_group_names[each.key]
      ServiceName = local.service_names[each.key]
    }
  )
}

# ==============================================================================
# TASK DEFINITIONS
# ==============================================================================

resource "aws_ecs_task_definition" "this" {
  for_each = var.services

  family                   = local.task_definition_names[each.key]
  cpu                      = each.value.cpu
  memory                   = each.value.memory
  network_mode             = each.value.network_mode
  requires_compatibilities = each.value.requires_compatibilities
  pid_mode                 = each.value.pid_mode
  ipc_mode                 = each.value.ipc_mode
  skip_destroy             = each.value.skip_destroy

  task_role_arn      = each.value.task_role_arn
  execution_role_arn = coalesce(each.value.execution_role_arn, try(aws_iam_role.task_exec[0].arn, null))

  container_definitions = jsonencode(local.container_definitions[each.key])

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

      properties = proxy_configuration.value.properties
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
      Name        = local.task_definition_names[each.key]
      ServiceName = local.service_names[each.key]
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# ==============================================================================
# ECS SERVICES (STANDARD)
# ==============================================================================

resource "aws_ecs_service" "this" {
  for_each = { for k, v in var.services : k => v if !v.ignore_task_definition_changes }

  name            = local.service_names[each.key]
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this[each.key].arn

  desired_count                      = each.value.desired_count
  launch_type                        = length(each.value.capacity_provider_strategy) > 0 ? null : each.value.launch_type
  platform_version                   = each.value.platform_version
  scheduling_strategy                = each.value.scheduling_strategy
  deployment_minimum_healthy_percent = each.value.deployment_minimum_healthy_percent
  deployment_maximum_percent         = each.value.deployment_maximum_percent
  enable_execute_command             = each.value.enable_execute_command
  enable_ecs_managed_tags            = each.value.enable_ecs_managed_tags
  propagate_tags                     = each.value.propagate_tags
  health_check_grace_period_seconds  = each.value.health_check_grace_period_seconds
  force_new_deployment               = each.value.force_new_deployment
  wait_for_steady_state              = each.value.wait_for_steady_state
  triggers                           = each.value.triggers

  # Network configuration (awsvpc mode)
  dynamic "network_configuration" {
    for_each = each.value.network_mode == "awsvpc" ? [1] : []
    content {
      subnets          = each.value.subnet_ids
      security_groups  = each.value.security_group_ids
      assign_public_ip = each.value.assign_public_ip
    }
  }

  # Capacity provider strategy
  dynamic "capacity_provider_strategy" {
    for_each = each.value.capacity_provider_strategy
    content {
      capacity_provider = capacity_provider_strategy.value.capacity_provider
      weight            = capacity_provider_strategy.value.weight
      base              = capacity_provider_strategy.value.base
    }
  }

  # Deployment circuit breaker
  dynamic "deployment_circuit_breaker" {
    for_each = each.value.deployment_circuit_breaker != null ? [each.value.deployment_circuit_breaker] : []
    content {
      enable   = deployment_circuit_breaker.value.enable
      rollback = deployment_circuit_breaker.value.rollback
    }
  }

  # Deployment alarms
  dynamic "alarms" {
    for_each = each.value.deployment_alarms != null ? [each.value.deployment_alarms] : []
    content {
      alarm_names = alarms.value.alarm_names
      enable      = alarms.value.enable
      rollback    = alarms.value.rollback
    }
  }

  # Load balancers
  dynamic "load_balancer" {
    for_each = each.value.load_balancers
    content {
      target_group_arn = load_balancer.value.target_group_arn
      container_name   = load_balancer.value.container_name
      container_port   = load_balancer.value.container_port
    }
  }

  # Service registries (Cloud Map)
  dynamic "service_registries" {
    for_each = each.value.service_registries != null ? [each.value.service_registries] : []
    content {
      registry_arn   = service_registries.value.registry_arn
      container_name = service_registries.value.container_name
      container_port = service_registries.value.container_port
      port           = service_registries.value.port
    }
  }

  # Service Connect
  dynamic "service_connect_configuration" {
    for_each = each.value.service_connect_configuration != null ? [each.value.service_connect_configuration] : []
    content {
      enabled   = service_connect_configuration.value.enabled
      namespace = service_connect_configuration.value.namespace

      dynamic "service" {
        for_each = service_connect_configuration.value.services != null ? service_connect_configuration.value.services : []
        content {
          port_name             = service.value.port_name
          discovery_name        = service.value.discovery_name
          ingress_port_override = service.value.ingress_port_override

          dynamic "client_alias" {
            for_each = service.value.client_alias != null ? [service.value.client_alias] : []
            content {
              port     = client_alias.value.port
              dns_name = client_alias.value.dns_name
            }
          }

          dynamic "timeout" {
            for_each = service.value.timeout != null ? [service.value.timeout] : []
            content {
              idle_timeout_seconds        = timeout.value.idle_timeout_seconds
              per_request_timeout_seconds = timeout.value.per_request_timeout_seconds
            }
          }

          dynamic "tls" {
            for_each = service.value.tls != null ? [service.value.tls] : []
            content {
              issuer_cert_authority {
                aws_pca_authority_arn = tls.value.issuer_cert_authority.aws_pca_authority_arn
              }
              kms_key  = tls.value.kms_key
              role_arn = tls.value.role_arn
            }
          }
        }
      }

      dynamic "log_configuration" {
        for_each = service_connect_configuration.value.log_configuration != null ? [service_connect_configuration.value.log_configuration] : []
        content {
          log_driver = log_configuration.value.log_driver
          options    = log_configuration.value.options
        }
      }
    }
  }

  # Ordered placement strategy
  dynamic "ordered_placement_strategy" {
    for_each = each.value.ordered_placement_strategy
    content {
      type  = ordered_placement_strategy.value.type
      field = ordered_placement_strategy.value.field
    }
  }

  # Placement constraints
  dynamic "placement_constraints" {
    for_each = each.value.placement_constraints
    content {
      type       = placement_constraints.value.type
      expression = placement_constraints.value.expression
    }
  }

  # EBS Volume configuration
  dynamic "volume_configuration" {
    for_each = each.value.volume_configuration != null ? [each.value.volume_configuration] : []
    content {
      name = volume_configuration.value.name

      managed_ebs_volume {
        role_arn         = volume_configuration.value.managed_ebs_volume.role_arn
        encrypted        = volume_configuration.value.managed_ebs_volume.encrypted
        kms_key_id       = volume_configuration.value.managed_ebs_volume.kms_key_id
        size_in_gb       = volume_configuration.value.managed_ebs_volume.size_in_gb
        volume_type      = volume_configuration.value.managed_ebs_volume.volume_type
        iops             = volume_configuration.value.managed_ebs_volume.iops
        throughput       = volume_configuration.value.managed_ebs_volume.throughput
        snapshot_id      = volume_configuration.value.managed_ebs_volume.snapshot_id
        file_system_type = volume_configuration.value.managed_ebs_volume.file_system_type
      }
    }
  }

  dynamic "timeouts" {
    for_each = each.value.timeouts != null ? [each.value.timeouts] : []
    content {
      create = timeouts.value.create
      update = timeouts.value.update
      delete = timeouts.value.delete
    }
  }

  tags = merge(
    local.tags_common,
    each.value.tags,
    {
      Name = local.service_names[each.key]
    }
  )

  depends_on = [
    aws_cloudwatch_log_group.service,
    aws_iam_role_policy_attachment.task_exec_additional,
    aws_iam_role_policy.task_exec,
  ]
}

# ==============================================================================
# ECS SERVICES (IGNORE TASK DEFINITION CHANGES)
# ==============================================================================

resource "aws_ecs_service" "ignore_task_definition" {
  for_each = { for k, v in var.services : k => v if v.ignore_task_definition_changes }

  name            = local.service_names[each.key]
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this[each.key].arn

  desired_count                      = each.value.desired_count
  launch_type                        = length(each.value.capacity_provider_strategy) > 0 ? null : each.value.launch_type
  platform_version                   = each.value.platform_version
  scheduling_strategy                = each.value.scheduling_strategy
  deployment_minimum_healthy_percent = each.value.deployment_minimum_healthy_percent
  deployment_maximum_percent         = each.value.deployment_maximum_percent
  enable_execute_command             = each.value.enable_execute_command
  enable_ecs_managed_tags            = each.value.enable_ecs_managed_tags
  propagate_tags                     = each.value.propagate_tags
  health_check_grace_period_seconds  = each.value.health_check_grace_period_seconds
  force_new_deployment               = each.value.force_new_deployment
  wait_for_steady_state              = each.value.wait_for_steady_state
  triggers                           = each.value.triggers

  dynamic "network_configuration" {
    for_each = each.value.network_mode == "awsvpc" ? [1] : []
    content {
      subnets          = each.value.subnet_ids
      security_groups  = each.value.security_group_ids
      assign_public_ip = each.value.assign_public_ip
    }
  }

  dynamic "capacity_provider_strategy" {
    for_each = each.value.capacity_provider_strategy
    content {
      capacity_provider = capacity_provider_strategy.value.capacity_provider
      weight            = capacity_provider_strategy.value.weight
      base              = capacity_provider_strategy.value.base
    }
  }

  dynamic "deployment_circuit_breaker" {
    for_each = each.value.deployment_circuit_breaker != null ? [each.value.deployment_circuit_breaker] : []
    content {
      enable   = deployment_circuit_breaker.value.enable
      rollback = deployment_circuit_breaker.value.rollback
    }
  }

  dynamic "alarms" {
    for_each = each.value.deployment_alarms != null ? [each.value.deployment_alarms] : []
    content {
      alarm_names = alarms.value.alarm_names
      enable      = alarms.value.enable
      rollback    = alarms.value.rollback
    }
  }

  dynamic "load_balancer" {
    for_each = each.value.load_balancers
    content {
      target_group_arn = load_balancer.value.target_group_arn
      container_name   = load_balancer.value.container_name
      container_port   = load_balancer.value.container_port
    }
  }

  dynamic "service_registries" {
    for_each = each.value.service_registries != null ? [each.value.service_registries] : []
    content {
      registry_arn   = service_registries.value.registry_arn
      container_name = service_registries.value.container_name
      container_port = service_registries.value.container_port
      port           = service_registries.value.port
    }
  }

  dynamic "service_connect_configuration" {
    for_each = each.value.service_connect_configuration != null ? [each.value.service_connect_configuration] : []
    content {
      enabled   = service_connect_configuration.value.enabled
      namespace = service_connect_configuration.value.namespace

      dynamic "service" {
        for_each = service_connect_configuration.value.services != null ? service_connect_configuration.value.services : []
        content {
          port_name             = service.value.port_name
          discovery_name        = service.value.discovery_name
          ingress_port_override = service.value.ingress_port_override

          dynamic "client_alias" {
            for_each = service.value.client_alias != null ? [service.value.client_alias] : []
            content {
              port     = client_alias.value.port
              dns_name = client_alias.value.dns_name
            }
          }

          dynamic "timeout" {
            for_each = service.value.timeout != null ? [service.value.timeout] : []
            content {
              idle_timeout_seconds        = timeout.value.idle_timeout_seconds
              per_request_timeout_seconds = timeout.value.per_request_timeout_seconds
            }
          }

          dynamic "tls" {
            for_each = service.value.tls != null ? [service.value.tls] : []
            content {
              issuer_cert_authority {
                aws_pca_authority_arn = tls.value.issuer_cert_authority.aws_pca_authority_arn
              }
              kms_key  = tls.value.kms_key
              role_arn = tls.value.role_arn
            }
          }
        }
      }

      dynamic "log_configuration" {
        for_each = service_connect_configuration.value.log_configuration != null ? [service_connect_configuration.value.log_configuration] : []
        content {
          log_driver = log_configuration.value.log_driver
          options    = log_configuration.value.options
        }
      }
    }
  }

  dynamic "ordered_placement_strategy" {
    for_each = each.value.ordered_placement_strategy
    content {
      type  = ordered_placement_strategy.value.type
      field = ordered_placement_strategy.value.field
    }
  }

  dynamic "placement_constraints" {
    for_each = each.value.placement_constraints
    content {
      type       = placement_constraints.value.type
      expression = placement_constraints.value.expression
    }
  }

  dynamic "volume_configuration" {
    for_each = each.value.volume_configuration != null ? [each.value.volume_configuration] : []
    content {
      name = volume_configuration.value.name

      managed_ebs_volume {
        role_arn         = volume_configuration.value.managed_ebs_volume.role_arn
        encrypted        = volume_configuration.value.managed_ebs_volume.encrypted
        kms_key_id       = volume_configuration.value.managed_ebs_volume.kms_key_id
        size_in_gb       = volume_configuration.value.managed_ebs_volume.size_in_gb
        volume_type      = volume_configuration.value.managed_ebs_volume.volume_type
        iops             = volume_configuration.value.managed_ebs_volume.iops
        throughput       = volume_configuration.value.managed_ebs_volume.throughput
        snapshot_id      = volume_configuration.value.managed_ebs_volume.snapshot_id
        file_system_type = volume_configuration.value.managed_ebs_volume.file_system_type
      }
    }
  }

  dynamic "timeouts" {
    for_each = each.value.timeouts != null ? [each.value.timeouts] : []
    content {
      create = timeouts.value.create
      update = timeouts.value.update
      delete = timeouts.value.delete
    }
  }

  tags = merge(
    local.tags_common,
    each.value.tags,
    {
      Name = local.service_names[each.key]
    }
  )

  depends_on = [
    aws_cloudwatch_log_group.service,
    aws_iam_role_policy_attachment.task_exec_additional,
    aws_iam_role_policy.task_exec,
  ]

  lifecycle {
    ignore_changes = [task_definition]
  }
}
