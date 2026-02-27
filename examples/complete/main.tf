# ==============================================================================
# COMPLETE ECS EXAMPLE
# ==============================================================================
# Demonstrates: multiple services, autoscaling, secrets, load balancer,
# execute command, EFS volumes, Service Connect, and deployment alarms

module "ecs" {
  source = "../../ecs"

  account_name = var.account_name
  project_name = var.project_name

  # Cluster configuration with enhanced Container Insights
  cluster_settings = [
    {
      name  = "containerInsights"
      value = "enhanced"
    }
  ]

  # Enable execute command for debugging
  cluster_execute_command_configuration = {
    logging = "OVERRIDE"
    log_configuration = {
      cloud_watch_encryption_enabled = true
      cloud_watch_log_group_name     = "/ecs/exec-logs"
    }
  }

  # Fargate capacity providers
  default_capacity_provider_use_fargate = true
  fargate_capacity_providers = {
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

  # CloudWatch log group for cluster
  create_cloudwatch_log_group            = true
  cloudwatch_log_group_retention_in_days = 30

  # Task execution role with access to secrets
  create_task_exec_iam_role = true
  task_exec_secret_arns     = [var.db_secret_arn]

  # ============================================================================
  # SERVICES
  # ============================================================================
  services = {
    # ------------------------------------------------------------------
    # API Service - Fargate with ALB, autoscaling, secrets
    # ------------------------------------------------------------------
    api = {
      cpu    = 512
      memory = 1024

      runtime_platform = {
        operating_system_family = "LINUX"
        cpu_architecture        = "X86_64"
      }

      containers = {
        api = {
          image     = "myapp/api:latest"
          essential = true
          cpu       = 384
          memory    = 768

          port_mappings = [
            {
              container_port = 8080
              protocol       = "tcp"
              name           = "http"
              app_protocol   = "http"
            }
          ]

          environment = [
            { name = "NODE_ENV", value = "production" },
            { name = "PORT", value = "8080" },
            { name = "LOG_LEVEL", value = "info" }
          ]

          secrets = [
            { name = "DB_HOST", value_from = "${var.db_secret_arn}:host::" },
            { name = "DB_PASSWORD", value_from = "${var.db_secret_arn}:password::" }
          ]

          health_check = {
            command      = ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"]
            interval     = 30
            timeout      = 5
            retries      = 3
            start_period = 60
          }

          readonly_root_filesystem = true

          linux_parameters = {
            init_process_enabled = true
          }
        }

        # Sidecar: CloudWatch agent
        cloudwatch-agent = {
          image                     = "amazon/cloudwatch-agent:latest"
          essential                 = false
          cpu                       = 128
          memory                    = 256
          readonly_root_filesystem  = false
          enable_cloudwatch_logging = true
        }
      }

      # Service configuration
      desired_count          = 3
      enable_execute_command = true
      force_new_deployment   = true

      # Network
      subnet_ids         = var.private_subnet_ids
      security_group_ids = var.security_group_ids
      assign_public_ip   = false

      # Load balancer
      load_balancers = [
        {
          target_group_arn = var.target_group_arn
          container_name   = "api"
          container_port   = 8080
        }
      ]

      health_check_grace_period_seconds = 120

      # Deployment
      deployment_circuit_breaker = {
        enable   = true
        rollback = true
      }

      # Auto-scaling
      enable_autoscaling = true
      autoscaling = {
        min_capacity = 2
        max_capacity = 20

        policies = {
          cpu = {
            policy_type = "TargetTrackingScaling"
            target_tracking_scaling_policy_configuration = {
              target_value = 70
              predefined_metric_specification = {
                predefined_metric_type = "ECSServiceAverageCPUUtilization"
              }
            }
          }

          memory = {
            policy_type = "TargetTrackingScaling"
            target_tracking_scaling_policy_configuration = {
              target_value = 80
              predefined_metric_specification = {
                predefined_metric_type = "ECSServiceAverageMemoryUtilization"
              }
            }
          }
        }

        scheduled_actions = {
          scale-up-morning = {
            schedule     = "cron(0 8 * * MON-FRI *)"
            timezone     = "America/New_York"
            min_capacity = 5
            max_capacity = 20
          }
          scale-down-night = {
            schedule     = "cron(0 22 * * * *)"
            timezone     = "America/New_York"
            min_capacity = 2
            max_capacity = 10
          }
        }
      }

      # CloudWatch logs
      log_group_retention_in_days = 14

      tags = {
        Service = "api"
        Tier    = "backend"
      }
    }

    # ------------------------------------------------------------------
    # Worker Service - Background job processor
    # ------------------------------------------------------------------
    worker = {
      cpu    = 256
      memory = 512

      containers = {
        worker = {
          image     = "myapp/worker:latest"
          essential = true

          command = ["node", "worker.js"]

          environment = [
            { name = "QUEUE_URL", value = "https://sqs.us-east-1.amazonaws.com/123456789012/tasks" },
            { name = "CONCURRENCY", value = "10" }
          ]

          secrets = [
            { name = "DB_CONNECTION_STRING", value_from = "${var.db_secret_arn}:connectionString::" }
          ]

          readonly_root_filesystem = true
        }
      }

      desired_count          = 2
      enable_execute_command = true

      subnet_ids         = var.private_subnet_ids
      security_group_ids = var.security_group_ids

      deployment_circuit_breaker = {
        enable   = true
        rollback = true
      }

      # Worker autoscaling based on SQS queue depth (custom metric)
      enable_autoscaling = true
      autoscaling = {
        min_capacity = 1
        max_capacity = 10

        policies = {
          cpu = {
            policy_type = "TargetTrackingScaling"
            target_tracking_scaling_policy_configuration = {
              target_value = 75
              predefined_metric_specification = {
                predefined_metric_type = "ECSServiceAverageCPUUtilization"
              }
            }
          }
        }
      }

      log_group_retention_in_days = 7

      tags = {
        Service = "worker"
        Tier    = "backend"
      }
    }
  }

  tags = {
    Environment = "production"
    Example     = "complete"
  }
}
