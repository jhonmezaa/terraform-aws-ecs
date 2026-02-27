# ==============================================================================
# COMMON VARIABLES
# ==============================================================================

variable "account_name" {
  description = "Account name used for resource naming convention"
  type        = string
}

variable "project_name" {
  description = "Project name used for resource naming convention"
  type        = string
}

variable "region_prefix" {
  description = "Override the auto-generated region prefix for resource naming"
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# ==============================================================================
# ECS CLUSTER
# ==============================================================================

variable "cluster_name" {
  description = "Override the auto-generated cluster name"
  type        = string
  default     = null
}

variable "cluster_settings" {
  description = "Configuration block(s) with cluster settings. e.g. containerInsights"
  type = list(object({
    name  = string
    value = string
  }))
  default = [
    {
      name  = "containerInsights"
      value = "enhanced"
    }
  ]
}

variable "cluster_execute_command_configuration" {
  description = "The details of the execute command configuration"
  type = object({
    kms_key_id = optional(string)
    logging    = optional(string, "DEFAULT")
    log_configuration = optional(object({
      cloud_watch_encryption_enabled = optional(bool, true)
      cloud_watch_log_group_name     = optional(string)
      s3_bucket_name                 = optional(string)
      s3_bucket_encryption_enabled   = optional(bool, true)
      s3_key_prefix                  = optional(string)
    }))
  })
  default = {}
}

variable "cluster_service_connect_defaults" {
  description = "Configures a default Service Connect namespace"
  type = object({
    namespace = string
  })
  default = null
}

# ==============================================================================
# CLOUDWATCH LOG GROUP (CLUSTER)
# ==============================================================================

variable "create_cloudwatch_log_group" {
  description = "Whether to create a CloudWatch log group for the ECS cluster"
  type        = bool
  default     = true
}

variable "cloudwatch_log_group_retention_in_days" {
  description = "Number of days to retain CloudWatch logs for the cluster"
  type        = number
  default     = 90
}

variable "cloudwatch_log_group_kms_key_id" {
  description = "KMS key ID for encrypting the CloudWatch log group"
  type        = string
  default     = null
}

variable "cloudwatch_log_group_tags" {
  description = "Additional tags for the CloudWatch log group"
  type        = map(string)
  default     = {}
}

# ==============================================================================
# CAPACITY PROVIDERS
# ==============================================================================

variable "default_capacity_provider_use_fargate" {
  description = "Whether to use Fargate as the default capacity provider strategy"
  type        = bool
  default     = true
}

variable "fargate_capacity_providers" {
  description = "Map of Fargate capacity provider definitions to associate with the cluster"
  type = map(object({
    default_capacity_provider_strategy = optional(object({
      weight = optional(number, 0)
      base   = optional(number, 0)
    }), {})
  }))
  default = {
    FARGATE = {
      default_capacity_provider_strategy = {
        weight = 50
        base   = 20
      }
    }
    FARGATE_SPOT = {
      default_capacity_provider_strategy = {
        weight = 50
      }
    }
  }
}

variable "autoscaling_capacity_providers" {
  description = "Map of autoscaling capacity provider definitions to create for the cluster"
  type = map(object({
    auto_scaling_group_arn         = string
    managed_termination_protection = optional(string, "DISABLED")

    managed_scaling = optional(object({
      instance_warmup_period    = optional(number)
      maximum_scaling_step_size = optional(number)
      minimum_scaling_step_size = optional(number)
      status                    = optional(string, "ENABLED")
      target_capacity           = optional(number, 100)
    }), {})

    managed_draining = optional(string, "ENABLED")

    default_capacity_provider_strategy = optional(object({
      weight = optional(number)
      base   = optional(number)
    }))

    tags = optional(map(string), {})
  }))
  default = {}
}

# ==============================================================================
# TASK EXECUTION IAM ROLE
# ==============================================================================

variable "create_task_exec_iam_role" {
  description = "Whether to create the task execution IAM role"
  type        = bool
  default     = true
}

variable "task_exec_iam_role_name" {
  description = "Override the task execution role name"
  type        = string
  default     = null
}

variable "task_exec_iam_role_path" {
  description = "Path for the task execution IAM role"
  type        = string
  default     = null
}

variable "task_exec_iam_role_description" {
  description = "Description of the task execution IAM role"
  type        = string
  default     = "ECS Task Execution IAM Role"
}

variable "task_exec_iam_role_permissions_boundary" {
  description = "ARN of the permissions boundary for the task execution IAM role"
  type        = string
  default     = null
}

variable "task_exec_iam_role_tags" {
  description = "Additional tags for the task execution IAM role"
  type        = map(string)
  default     = {}
}

variable "task_exec_iam_role_policies" {
  description = "Map of IAM policy ARNs to attach to the task execution role"
  type        = map(string)
  default     = {}
}

variable "task_exec_iam_statements" {
  description = "Additional IAM policy statements for the task execution role inline policy"
  type = list(object({
    sid       = optional(string)
    effect    = optional(string, "Allow")
    actions   = list(string)
    resources = list(string)
    conditions = optional(list(object({
      test     = string
      variable = string
      values   = list(string)
    })), [])
  }))
  default = []
}

variable "task_exec_ssm_param_arns" {
  description = "List of SSM parameter ARNs the task execution role can access"
  type        = list(string)
  default     = []
}

variable "task_exec_secret_arns" {
  description = "List of Secrets Manager ARNs the task execution role can access"
  type        = list(string)
  default     = []
}

# ==============================================================================
# STANDALONE TASK DEFINITIONS
# ==============================================================================

variable "task_definitions" {
  description = "Map of standalone task definitions (for RunTask, scheduled tasks, one-off jobs)"
  type = map(object({
    # Naming
    name           = optional(string)
    log_group_name = optional(string)

    # Task Definition
    cpu                      = optional(number, 256)
    memory                   = optional(number, 512)
    network_mode             = optional(string, "awsvpc")
    requires_compatibilities = optional(list(string), ["FARGATE"])
    task_role_arn            = optional(string)
    execution_role_arn       = optional(string)
    pid_mode                 = optional(string)
    ipc_mode                 = optional(string)
    skip_destroy             = optional(bool)

    runtime_platform = optional(object({
      operating_system_family = optional(string, "LINUX")
      cpu_architecture        = optional(string, "X86_64")
    }))

    ephemeral_storage = optional(object({
      size_in_gib = number
    }))

    proxy_configuration = optional(object({
      type           = optional(string, "APPMESH")
      container_name = string
      properties     = optional(map(string), {})
    }))

    # Containers
    containers = map(object({
      image                    = string
      cpu                      = optional(number)
      memory                   = optional(number)
      memory_reservation       = optional(number)
      essential                = optional(bool, true)
      command                  = optional(list(string))
      entry_point              = optional(list(string))
      working_directory        = optional(string)
      readonly_root_filesystem = optional(bool, true)
      user                     = optional(string)
      privileged               = optional(bool)
      interactive              = optional(bool)
      pseudo_terminal          = optional(bool)
      stop_timeout             = optional(number)
      start_timeout            = optional(number)

      enable_cloudwatch_logging = optional(bool, true)

      port_mappings = optional(list(object({
        container_port = number
        host_port      = optional(number)
        protocol       = optional(string, "tcp")
        name           = optional(string)
        app_protocol   = optional(string)
      })), [])

      environment = optional(list(object({
        name  = string
        value = string
      })), [])

      environment_files = optional(list(object({
        value = string
        type  = optional(string, "s3")
      })), [])

      secrets = optional(list(object({
        name       = string
        value_from = string
      })), [])

      health_check = optional(object({
        command      = list(string)
        interval     = optional(number, 30)
        timeout      = optional(number, 5)
        retries      = optional(number, 3)
        start_period = optional(number, 0)
      }))

      log_configuration = optional(object({
        log_driver = optional(string, "awslogs")
        options    = optional(map(string))
      }))

      mount_points = optional(list(object({
        source_volume  = string
        container_path = string
        read_only      = optional(bool, false)
      })), [])

      volumes_from = optional(list(object({
        source_container = string
        read_only        = optional(bool, false)
      })), [])

      depends_on_containers = optional(list(object({
        container_name = string
        condition      = string
      })), [])

      linux_parameters = optional(object({
        capabilities = optional(object({
          add  = optional(list(string), [])
          drop = optional(list(string), [])
        }))
        init_process_enabled = optional(bool)
      }))

      firelens_configuration = optional(object({
        type    = string
        options = optional(map(string))
      }))

      docker_labels = optional(map(string), {})

      ulimits = optional(list(object({
        name       = string
        soft_limit = number
        hard_limit = number
      })), [])

      extra_hosts = optional(list(object({
        hostname   = string
        ip_address = string
      })))

      resource_requirements = optional(list(object({
        type  = string
        value = string
      })), [])

      system_controls = optional(list(object({
        namespace = string
        value     = string
      })), [])
    }))

    # Volumes
    volumes = optional(list(object({
      name      = string
      host_path = optional(string)

      docker_volume_configuration = optional(object({
        scope         = optional(string)
        autoprovision = optional(bool)
        driver        = optional(string)
        driver_opts   = optional(map(string))
        labels        = optional(map(string))
      }))

      efs_volume_configuration = optional(object({
        file_system_id          = string
        root_directory          = optional(string)
        transit_encryption      = optional(string)
        transit_encryption_port = optional(number)
        authorization_config = optional(object({
          access_point_id = optional(string)
          iam             = optional(string)
        }))
      }))
    })), [])

    # CloudWatch
    create_log_group            = optional(bool, true)
    log_group_retention_in_days = optional(number, 30)
    log_group_kms_key_id        = optional(string)
    log_group_tags              = optional(map(string), {})

    # Tags
    tags = optional(map(string), {})
  }))
  default = {}
}

# ==============================================================================
# ECS SERVICES
# ==============================================================================

variable "services" {
  description = "Map of ECS service definitions to create"
  type = map(object({
    # Naming
    name                 = optional(string)
    task_definition_name = optional(string)
    log_group_name       = optional(string)

    # Task Definition
    cpu                      = optional(number, 256)
    memory                   = optional(number, 512)
    network_mode             = optional(string, "awsvpc")
    requires_compatibilities = optional(list(string), ["FARGATE"])
    task_role_arn            = optional(string)
    execution_role_arn       = optional(string)
    pid_mode                 = optional(string)
    ipc_mode                 = optional(string)
    skip_destroy             = optional(bool)

    runtime_platform = optional(object({
      operating_system_family = optional(string, "LINUX")
      cpu_architecture        = optional(string, "X86_64")
    }))

    ephemeral_storage = optional(object({
      size_in_gib = number
    }))

    proxy_configuration = optional(object({
      type           = optional(string, "APPMESH")
      container_name = string
      properties     = optional(map(string), {})
    }))

    # Containers
    containers = map(object({
      image                    = string
      cpu                      = optional(number)
      memory                   = optional(number)
      memory_reservation       = optional(number)
      essential                = optional(bool, true)
      command                  = optional(list(string))
      entry_point              = optional(list(string))
      working_directory        = optional(string)
      readonly_root_filesystem = optional(bool, true)
      user                     = optional(string)
      privileged               = optional(bool)
      interactive              = optional(bool)
      pseudo_terminal          = optional(bool)
      stop_timeout             = optional(number)
      start_timeout            = optional(number)

      enable_cloudwatch_logging = optional(bool, true)

      port_mappings = optional(list(object({
        container_port = number
        host_port      = optional(number)
        protocol       = optional(string, "tcp")
        name           = optional(string)
        app_protocol   = optional(string)
      })), [])

      environment = optional(list(object({
        name  = string
        value = string
      })), [])

      environment_files = optional(list(object({
        value = string
        type  = optional(string, "s3")
      })), [])

      secrets = optional(list(object({
        name       = string
        value_from = string
      })), [])

      health_check = optional(object({
        command      = list(string)
        interval     = optional(number, 30)
        timeout      = optional(number, 5)
        retries      = optional(number, 3)
        start_period = optional(number, 0)
      }))

      log_configuration = optional(object({
        log_driver = optional(string, "awslogs")
        options    = optional(map(string))
      }))

      mount_points = optional(list(object({
        source_volume  = string
        container_path = string
        read_only      = optional(bool, false)
      })), [])

      volumes_from = optional(list(object({
        source_container = string
        read_only        = optional(bool, false)
      })), [])

      depends_on_containers = optional(list(object({
        container_name = string
        condition      = string
      })), [])

      linux_parameters = optional(object({
        capabilities = optional(object({
          add  = optional(list(string), [])
          drop = optional(list(string), [])
        }))
        init_process_enabled = optional(bool)
      }))

      firelens_configuration = optional(object({
        type    = string
        options = optional(map(string))
      }))

      docker_labels = optional(map(string), {})

      ulimits = optional(list(object({
        name       = string
        soft_limit = number
        hard_limit = number
      })), [])

      extra_hosts = optional(list(object({
        hostname   = string
        ip_address = string
      })))

      resource_requirements = optional(list(object({
        type  = string
        value = string
      })), [])

      system_controls = optional(list(object({
        namespace = string
        value     = string
      })), [])
    }))

    # Service Configuration
    desired_count                      = optional(number, 1)
    launch_type                        = optional(string)
    platform_version                   = optional(string)
    scheduling_strategy                = optional(string, "REPLICA")
    deployment_minimum_healthy_percent = optional(number, 100)
    deployment_maximum_percent         = optional(number, 200)
    enable_execute_command             = optional(bool, false)
    enable_ecs_managed_tags            = optional(bool, true)
    propagate_tags                     = optional(string)
    health_check_grace_period_seconds  = optional(number)
    force_new_deployment               = optional(bool, true)
    wait_for_steady_state              = optional(bool)
    triggers                           = optional(map(string), {})

    # Capacity Provider Strategy
    capacity_provider_strategy = optional(list(object({
      capacity_provider = string
      weight            = optional(number)
      base              = optional(number)
    })), [])

    # Network Configuration
    subnet_ids         = optional(list(string), [])
    security_group_ids = optional(list(string), [])
    assign_public_ip   = optional(bool, false)

    # Deployment Circuit Breaker
    deployment_circuit_breaker = optional(object({
      enable   = bool
      rollback = bool
    }))

    # Deployment Alarms
    deployment_alarms = optional(object({
      alarm_names = list(string)
      enable      = bool
      rollback    = bool
    }))

    # Load Balancers
    load_balancers = optional(list(object({
      target_group_arn = string
      container_name   = string
      container_port   = number
    })), [])

    # Service Registries (Cloud Map)
    service_registries = optional(object({
      registry_arn   = string
      container_name = optional(string)
      container_port = optional(number)
      port           = optional(number)
    }))

    # Service Connect
    service_connect_configuration = optional(object({
      enabled   = bool
      namespace = optional(string)
      services = optional(list(object({
        port_name             = string
        discovery_name        = optional(string)
        ingress_port_override = optional(number)
        client_alias = optional(object({
          port     = number
          dns_name = optional(string)
        }))
        timeout = optional(object({
          idle_timeout_seconds        = optional(number)
          per_request_timeout_seconds = optional(number)
        }))
        tls = optional(object({
          issuer_cert_authority = object({
            aws_pca_authority_arn = string
          })
          kms_key  = optional(string)
          role_arn = optional(string)
        }))
      })))
      log_configuration = optional(object({
        log_driver = optional(string, "awslogs")
        options    = optional(map(string))
      }))
    }))

    # Ordered Placement Strategy (EC2 launch type)
    ordered_placement_strategy = optional(list(object({
      type  = string
      field = optional(string)
    })), [])

    # Placement Constraints
    placement_constraints = optional(list(object({
      type       = string
      expression = optional(string)
    })), [])

    # Volumes
    volumes = optional(list(object({
      name      = string
      host_path = optional(string)

      docker_volume_configuration = optional(object({
        scope         = optional(string)
        autoprovision = optional(bool)
        driver        = optional(string)
        driver_opts   = optional(map(string))
        labels        = optional(map(string))
      }))

      efs_volume_configuration = optional(object({
        file_system_id          = string
        root_directory          = optional(string)
        transit_encryption      = optional(string)
        transit_encryption_port = optional(number)
        authorization_config = optional(object({
          access_point_id = optional(string)
          iam             = optional(string)
        }))
      }))
    })), [])

    # EBS Volume Configuration
    volume_configuration = optional(object({
      name = string
      managed_ebs_volume = object({
        role_arn         = optional(string)
        encrypted        = optional(bool, true)
        kms_key_id       = optional(string)
        size_in_gb       = optional(number)
        volume_type      = optional(string)
        iops             = optional(number)
        throughput       = optional(number)
        snapshot_id      = optional(string)
        file_system_type = optional(string)
      })
    }))

    # Auto-scaling
    enable_autoscaling = optional(bool, false)
    autoscaling = optional(object({
      min_capacity = optional(number, 1)
      max_capacity = optional(number, 10)

      policies = optional(map(object({
        policy_type = optional(string, "TargetTrackingScaling")

        target_tracking_scaling_policy_configuration = optional(object({
          target_value       = number
          scale_in_cooldown  = optional(number, 300)
          scale_out_cooldown = optional(number, 300)

          predefined_metric_specification = optional(object({
            predefined_metric_type = string
            resource_label         = optional(string)
          }))

          customized_metric_specification = optional(object({
            metrics = optional(list(object({
              id         = string
              label      = optional(string)
              expression = optional(string)
              metric_stat = optional(object({
                metric = object({
                  metric_name = string
                  namespace   = string
                  dimensions = optional(list(object({
                    name  = string
                    value = string
                  })))
                })
                stat = string
                unit = optional(string)
              }))
              return_data = optional(bool)
            })))
          }))
        }))
      })), {})

      scheduled_actions = optional(map(object({
        schedule     = string
        timezone     = optional(string)
        min_capacity = optional(number)
        max_capacity = optional(number)
        start_time   = optional(string)
        end_time     = optional(string)
      })), {})
    }))

    # Lifecycle
    ignore_task_definition_changes = optional(bool, false)

    # CloudWatch
    create_log_group            = optional(bool, true)
    log_group_retention_in_days = optional(number, 30)
    log_group_kms_key_id        = optional(string)
    log_group_tags              = optional(map(string), {})

    # Service tags
    tags = optional(map(string), {})

    # Timeouts
    timeouts = optional(object({
      create = optional(string)
      update = optional(string)
      delete = optional(string)
    }))
  }))
  default = {}
}
