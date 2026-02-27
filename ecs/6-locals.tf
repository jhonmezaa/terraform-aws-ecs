# ==============================================================================
# LOCALS
# ==============================================================================

locals {
  # Region prefix mapping for resource naming
  region_prefix_map = {
    "us-east-1"      = "ause1"
    "us-east-2"      = "ause2"
    "us-west-1"      = "usw1"
    "us-west-2"      = "usw2"
    "af-south-1"     = "afs1"
    "ap-east-1"      = "ape1"
    "ap-south-1"     = "aps1"
    "ap-south-2"     = "aps2"
    "ap-southeast-1" = "apse1"
    "ap-southeast-2" = "apse2"
    "ap-southeast-3" = "apse3"
    "ap-southeast-4" = "apse4"
    "ap-northeast-1" = "apne1"
    "ap-northeast-2" = "apne2"
    "ap-northeast-3" = "apne3"
    "ca-central-1"   = "cac1"
    "ca-west-1"      = "caw1"
    "eu-central-1"   = "euc1"
    "eu-central-2"   = "euc2"
    "eu-west-1"      = "euw1"
    "eu-west-2"      = "euw2"
    "eu-west-3"      = "euw3"
    "eu-south-1"     = "eus1"
    "eu-south-2"     = "eus2"
    "eu-north-1"     = "eun1"
    "il-central-1"   = "ilc1"
    "me-south-1"     = "mes1"
    "me-central-1"   = "mec1"
    "sa-east-1"      = "sae1"
  }

  region_prefix = coalesce(var.region_prefix, lookup(local.region_prefix_map, data.aws_region.current.id, data.aws_region.current.id))
  account_id    = data.aws_caller_identity.current.account_id
  partition     = data.aws_partition.current.partition

  # Cluster naming
  cluster_name = coalesce(
    var.cluster_name,
    "${local.region_prefix}-ecs-cluster-${var.account_name}-${var.project_name}"
  )

  # Tags common to all resources
  tags_common = merge(
    {
      "ManagedBy"   = "Terraform"
      "Module"      = "terraform-aws-ecs"
      "AccountName" = var.account_name
      "ProjectName" = var.project_name
      "Region"      = data.aws_region.current.id
    },
    var.tags
  )

  # ==============================================================================
  # STANDALONE TASK DEFINITION LOCALS
  # ==============================================================================

  standalone_td_names = {
    for k, v in var.task_definitions : k => coalesce(
      v.name,
      "${local.region_prefix}-ecs-td-${var.account_name}-${var.project_name}-${k}"
    )
  }

  standalone_td_log_group_names = {
    for k, v in var.task_definitions : k => coalesce(
      v.log_group_name,
      "/ecs/${local.cluster_name}/tasks/${k}"
    )
  }

  # ==============================================================================
  # SERVICE LOCALS
  # ==============================================================================

  # Build service names
  service_names = {
    for k, v in var.services : k => coalesce(
      v.name,
      "${local.region_prefix}-ecs-svc-${var.account_name}-${var.project_name}-${k}"
    )
  }

  # Build task definition names
  task_definition_names = {
    for k, v in var.services : k => coalesce(
      v.task_definition_name,
      "${local.region_prefix}-ecs-td-${var.account_name}-${var.project_name}-${k}"
    )
  }

  # Build CloudWatch log group names per service
  log_group_names = {
    for k, v in var.services : k => coalesce(
      v.log_group_name,
      "/ecs/${local.cluster_name}/${k}"
    )
  }

  # ==============================================================================
  # CONTAINER DEFINITIONS (shared builder for services and standalone TDs)
  # ==============================================================================

  # Merge all sources that need container definitions built
  all_container_sources = merge(
    { for k, v in var.services : k => { containers = v.containers, log_group_name = local.log_group_names[k] } },
    { for k, v in var.task_definitions : "standalone/${k}" => { containers = v.containers, log_group_name = local.standalone_td_log_group_names[k] } }
  )

  # Build container definitions JSON for services and standalone task definitions
  all_container_definitions = {
    for source_key, source in local.all_container_sources : source_key => [
      for container_key, container in source.containers : merge(
        {
          name      = container_key
          image     = container.image
          essential = container.essential
        },

        # CPU / Memory
        container.cpu != null ? { cpu = container.cpu } : {},
        container.memory != null ? { memory = container.memory } : {},
        container.memory_reservation != null ? { memoryReservation = container.memory_reservation } : {},

        # Command / Entrypoint
        container.command != null ? { command = container.command } : {},
        container.entry_point != null ? { entryPoint = container.entry_point } : {},
        container.working_directory != null ? { workingDirectory = container.working_directory } : {},

        # Read-only root filesystem
        { readonlyRootFilesystem = container.readonly_root_filesystem },

        # Port mappings
        length(container.port_mappings) > 0 ? {
          portMappings = [
            for pm in container.port_mappings : merge(
              { containerPort = pm.container_port },
              pm.host_port != null ? { hostPort = pm.host_port } : { hostPort = pm.container_port },
              pm.protocol != null ? { protocol = pm.protocol } : {},
              pm.name != null ? { name = pm.name } : {},
              pm.app_protocol != null ? { appProtocol = pm.app_protocol } : {}
            )
          ]
        } : {},

        # Environment variables
        length(container.environment) > 0 ? {
          environment = [
            for env in container.environment : {
              name  = env.name
              value = env.value
            }
          ]
        } : {},

        # Environment files (S3)
        length(container.environment_files) > 0 ? {
          environmentFiles = [
            for ef in container.environment_files : {
              value = ef.value
              type  = ef.type
            }
          ]
        } : {},

        # Secrets
        length(container.secrets) > 0 ? {
          secrets = [
            for s in container.secrets : {
              name      = s.name
              valueFrom = s.value_from
            }
          ]
        } : {},

        # Health check
        container.health_check != null ? {
          healthCheck = merge(
            { command = container.health_check.command },
            container.health_check.interval != null ? { interval = container.health_check.interval } : {},
            container.health_check.timeout != null ? { timeout = container.health_check.timeout } : {},
            container.health_check.retries != null ? { retries = container.health_check.retries } : {},
            container.health_check.start_period != null ? { startPeriod = container.health_check.start_period } : {}
          )
        } : {},

        # Log configuration - default to awslogs
        container.enable_cloudwatch_logging ? {
          logConfiguration = merge(
            { logDriver = container.log_configuration != null ? container.log_configuration.log_driver : "awslogs" },
            {
              options = container.log_configuration != null && container.log_configuration.options != null ? container.log_configuration.options : {
                "awslogs-group"         = source.log_group_name
                "awslogs-region"        = data.aws_region.current.id
                "awslogs-stream-prefix" = container_key
              }
            }
          )
        } : {},

        # Mount points
        length(container.mount_points) > 0 ? {
          mountPoints = [
            for mp in container.mount_points : {
              sourceVolume  = mp.source_volume
              containerPath = mp.container_path
              readOnly      = mp.read_only
            }
          ]
        } : {},

        # Volumes from
        length(container.volumes_from) > 0 ? {
          volumesFrom = [
            for vf in container.volumes_from : {
              sourceContainer = vf.source_container
              readOnly        = vf.read_only
            }
          ]
        } : {},

        # Container dependencies
        length(container.depends_on_containers) > 0 ? {
          dependsOn = [
            for dep in container.depends_on_containers : {
              containerName = dep.container_name
              condition     = dep.condition
            }
          ]
        } : {},

        # Linux parameters
        container.linux_parameters != null ? {
          linuxParameters = merge(
            container.linux_parameters.capabilities != null ? {
              capabilities = {
                add  = container.linux_parameters.capabilities.add
                drop = container.linux_parameters.capabilities.drop
              }
            } : {},
            container.linux_parameters.init_process_enabled != null ? { initProcessEnabled = container.linux_parameters.init_process_enabled } : {}
          )
        } : {},

        # Firelens
        container.firelens_configuration != null ? {
          firelensConfiguration = merge(
            { type = container.firelens_configuration.type },
            container.firelens_configuration.options != null ? { options = container.firelens_configuration.options } : {}
          )
        } : {},

        # Docker labels
        container.docker_labels != null && length(container.docker_labels) > 0 ? { dockerLabels = container.docker_labels } : {},

        # Ulimits
        length(container.ulimits) > 0 ? {
          ulimits = [
            for u in container.ulimits : {
              name      = u.name
              softLimit = u.soft_limit
              hardLimit = u.hard_limit
            }
          ]
        } : {},

        # User
        container.user != null ? { user = container.user } : {},

        # Privileged
        container.privileged != null ? { privileged = container.privileged } : {},

        # Interactive
        container.interactive != null ? { interactive = container.interactive } : {},
        container.pseudo_terminal != null ? { pseudoTerminal = container.pseudo_terminal } : {},

        # Extra hosts
        container.extra_hosts != null && length(container.extra_hosts) > 0 ? {
          extraHosts = [
            for eh in container.extra_hosts : {
              hostname  = eh.hostname
              ipAddress = eh.ip_address
            }
          ]
        } : {},

        # Resource requirements (GPU)
        length(container.resource_requirements) > 0 ? {
          resourceRequirements = [
            for rr in container.resource_requirements : {
              type  = rr.type
              value = rr.value
            }
          ]
        } : {},

        # System controls
        length(container.system_controls) > 0 ? {
          systemControls = [
            for sc in container.system_controls : {
              namespace = sc.namespace
              value     = sc.value
            }
          ]
        } : {},

        # Timeouts
        container.stop_timeout != null ? { stopTimeout = container.stop_timeout } : {},
        container.start_timeout != null ? { startTimeout = container.start_timeout } : {}
      )
    ]
  }

  # Split container definitions back to their sources
  container_definitions = {
    for k, v in var.services : k => local.all_container_definitions[k]
  }

  standalone_container_definitions = {
    for k, v in var.task_definitions : k => local.all_container_definitions["standalone/${k}"]
  }
}
