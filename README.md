# terraform-aws-ecs

Terraform module for AWS ECS (Elastic Container Service) with clusters, Fargate/EC2 capacity providers, services, task definitions, auto-scaling, and IAM roles.

## Features

### ECS Cluster
- Container Insights (enhanced mode by default)
- Execute command configuration with CloudWatch/S3 logging
- Service Connect defaults namespace
- Cluster-level CloudWatch log group with KMS encryption

### Capacity Providers
- **Fargate**: FARGATE and FARGATE_SPOT with configurable default strategy (weight/base)
- **EC2 Auto Scaling**: Custom capacity providers backed by Auto Scaling Groups
  - Managed scaling with warmup period and step sizes
  - Managed termination protection
  - Managed draining

### ECS Services
- Multiple services via `for_each` on a single `services` map
- Fargate and EC2 launch types
- Network configuration (awsvpc mode with subnets, security groups, public IP)
- Capacity provider strategy per service
- Deployment circuit breaker with automatic rollback
- Deployment alarms integration
- Load balancer integration (multiple target groups)
- Service registries (AWS Cloud Map)
- Service Connect with TLS, timeouts, and log configuration
- Ordered placement strategy and constraints (EC2)
- EBS managed volume configuration
- Force new deployment, configurable timeouts
- `ignore_task_definition_changes` lifecycle for external deployments (CI/CD)

### Task Definitions
- **Service-based**: Created alongside ECS services
- **Standalone**: For `RunTask`, EventBridge scheduled tasks, cron jobs, one-off tasks
- Runtime platform (LINUX/WINDOWS, X86_64/ARM64)
- Ephemeral storage, proxy configuration (App Mesh)
- Volumes: host path, Docker volumes, EFS with authorization config

### Container Definitions
Built entirely via locals (no external JSON files):
- Port mappings with `app_protocol` (Service Connect)
- Environment variables and environment files (S3)
- Secrets from Secrets Manager and SSM Parameter Store
- Health checks with configurable intervals/timeouts/retries
- CloudWatch Logs (`awslogs` driver, auto-configured)
- FireLens logging (`awsfirelens` driver with custom options)
- Mount points and volumes from other containers
- Container dependencies with conditions
- Linux parameters (capabilities, init process)
- Docker labels, ulimits, resource requirements, system controls
- Read-only root filesystem (enabled by default)
- Extra hosts, user/working directory, start/stop timeouts

### Auto-scaling
- Application Auto Scaling target per service
- **Target tracking policies**: CPU, Memory, custom metrics with math expressions
- **Scheduled actions**: Timezone-aware with min/max capacity changes
- Configurable scale-in/out cooldowns

### IAM
- **Task Execution Role**: `AmazonECSTaskExecutionRolePolicy` + inline policy for Secrets Manager/SSM access, additional managed policies, confused deputy protection, permissions boundary
- **Per-service Task Roles**: Created via `create_task_role` boolean, `AmazonSSMManagedInstanceCore` for execute command, additional managed policies via `task_role_policy_arns`

## Naming Convention

Resources follow the standard naming pattern:

```
{region_prefix}-ecs-{resource}-{account_name}-{project_name}[-{suffix}]
```

Examples:
- Cluster: `ause1-ecs-cluster-prod-myapp`
- Service: `ause1-ecs-svc-prod-myapp-api`
- Task Definition: `ause1-ecs-td-prod-myapp-api`
- Task Execution Role: `ause1-ecs-task-exec-role-prod-myapp`
- Task Role: `ause1-iam-role-prod-myapp-api-task`

Region prefixes are auto-detected (e.g., `us-east-1` -> `ause1`). Toggle with `use_region_prefix`.

## Usage

### Basic Fargate Service

```hcl
module "ecs" {
  source = "./terraform-aws-ecs/ecs"

  account_name = "prod"
  project_name = "myapp"

  services = {
    web = {
      cpu    = 256
      memory = 512

      containers = {
        nginx = {
          image = "nginx:latest"
          port_mappings = [
            {
              container_port = 80
              protocol       = "tcp"
            }
          ]
        }
      }

      desired_count    = 2
      subnet_ids       = ["subnet-xxx", "subnet-yyy"]
      security_group_ids = ["sg-xxx"]

      deployment_circuit_breaker = {
        enable   = true
        rollback = true
      }
    }
  }
}
```

### Service with HTTPS, Secrets, Auto-scaling and Load Balancer

```hcl
module "ecs" {
  source = "./terraform-aws-ecs/ecs"

  account_name = "prod"
  project_name = "platform"

  # Secrets Manager access for task execution role
  task_exec_secret_arns = [
    "arn:aws:secretsmanager:us-east-1:123456789012:secret:db-creds-*"
  ]

  services = {
    api = {
      cpu    = 1024
      memory = 2048

      containers = {
        app = {
          image     = "123456789012.dkr.ecr.us-east-1.amazonaws.com/api:latest"
          cpu       = 896
          memory    = 1792
          essential = true

          port_mappings = [
            {
              container_port = 8080
              protocol       = "tcp"
              name           = "http"
              app_protocol   = "http"
            }
          ]

          environment = [
            { name = "NODE_ENV", value = "production" }
          ]

          secrets = [
            { name = "DB_PASSWORD", value_from = "arn:aws:secretsmanager:us-east-1:123456789012:secret:db-creds:password::" }
          ]

          health_check = {
            command  = ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"]
            interval = 30
            timeout  = 5
            retries  = 3
          }
        }
      }

      # Network
      desired_count      = 3
      subnet_ids         = ["subnet-xxx", "subnet-yyy", "subnet-zzz"]
      security_group_ids = ["sg-xxx"]

      # Load balancer
      load_balancers = [
        {
          target_group_arn = "arn:aws:elasticloadbalancing:...:targetgroup/api/xxx"
          container_name   = "app"
          container_port   = 8080
        }
      ]

      # Per-service task role
      create_task_role    = true
      task_role_policy_arns = {
        s3_access = "arn:aws:iam::policy/AmazonS3ReadOnlyAccess"
      }

      # Auto-scaling
      enable_autoscaling = true
      autoscaling = {
        min_capacity = 2
        max_capacity = 20

        policies = {
          cpu = {
            target_tracking_scaling_policy_configuration = {
              target_value = 70
              predefined_metric_specification = {
                predefined_metric_type = "ECSServiceAverageCPUUtilization"
              }
            }
          }
          memory = {
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
            schedule     = "cron(0 8 * * ? *)"
            timezone     = "America/New_York"
            min_capacity = 5
          }
          scale-down-night = {
            schedule     = "cron(0 22 * * ? *)"
            timezone     = "America/New_York"
            min_capacity = 2
          }
        }
      }

      # Deployment
      deployment_circuit_breaker = {
        enable   = true
        rollback = true
      }

      enable_execute_command = true
      force_new_deployment   = true
    }
  }

  tags = {
    Environment = "prod"
  }
}
```

### Standalone Task Definition (RunTask / Scheduled)

```hcl
module "ecs" {
  source = "./terraform-aws-ecs/ecs"

  account_name = "prod"
  project_name = "myapp"

  task_definitions = {
    migration = {
      cpu    = 512
      memory = 1024

      containers = {
        migrate = {
          image   = "123456789012.dkr.ecr.us-east-1.amazonaws.com/api:latest"
          command = ["npm", "run", "migrate"]

          environment = [
            { name = "NODE_ENV", value = "production" }
          ]

          secrets = [
            { name = "DATABASE_URL", value_from = "arn:aws:secretsmanager:..." }
          ]
        }
      }
    }
  }

  services = {} # No services, just task definitions
}
```

### EFS Volume with Service Connect

```hcl
module "ecs" {
  source = "./terraform-aws-ecs/ecs"

  account_name = "prod"
  project_name = "myapp"

  services = {
    app = {
      cpu    = 512
      memory = 1024

      containers = {
        web = {
          image = "nginx:latest"
          port_mappings = [
            {
              container_port = 80
              name           = "http"
              app_protocol   = "http"
            }
          ]
          mount_points = [
            {
              source_volume  = "data"
              container_path = "/data"
              read_only      = false
            }
          ]
        }
      }

      volumes = [
        {
          name = "data"
          efs_volume_configuration = {
            file_system_id     = "fs-xxx"
            transit_encryption = "ENABLED"
            authorization_config = {
              access_point_id = "fsap-xxx"
              iam             = "ENABLED"
            }
          }
        }
      ]

      subnet_ids         = ["subnet-xxx", "subnet-yyy"]
      security_group_ids = ["sg-xxx"]

      service_connect_configuration = {
        enabled   = true
        namespace = "arn:aws:servicediscovery:us-east-1:123456789012:namespace/ns-xxx"
        services = [
          {
            port_name      = "http"
            discovery_name = "web"
            client_alias = {
              port     = 80
              dns_name = "web.local"
            }
          }
        ]
      }
    }
  }
}
```

## Examples

- [Basic](examples/basic/) - Simple Fargate service with NGINX
- [Complete](examples/complete/) - Multiple services, secrets, auto-scaling, load balancer

## Requirements

| Name | Version |
|------|---------|
| terraform | ~> 1.0 |
| aws | ~> 6.0 |

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `account_name` | Account name for resource naming | `string` | - |
| `project_name` | Project name for resource naming | `string` | - |
| `region_prefix` | Override auto-generated region prefix | `string` | `null` |
| `use_region_prefix` | Include region prefix in names | `bool` | `true` |
| `tags` | Additional tags for all resources | `map(string)` | `{}` |
| **Cluster** | | | |
| `cluster_name` | Override cluster name | `string` | `null` |
| `cluster_settings` | Cluster settings (e.g., containerInsights) | `list(object)` | `[{name="containerInsights", value="enhanced"}]` |
| `cluster_execute_command_configuration` | Execute command logging config | `object` | `{}` |
| `cluster_service_connect_defaults` | Service Connect namespace | `object` | `null` |
| **CloudWatch** | | | |
| `create_cloudwatch_log_group` | Create cluster log group | `bool` | `true` |
| `cloudwatch_log_group_retention_in_days` | Log retention days | `number` | `90` |
| `cloudwatch_log_group_kms_key_id` | KMS key for log encryption | `string` | `null` |
| **Capacity Providers** | | | |
| `default_capacity_provider_use_fargate` | Use Fargate as default | `bool` | `true` |
| `fargate_capacity_providers` | Fargate providers with strategies | `map(object)` | `{FARGATE={...}, FARGATE_SPOT={...}}` |
| `autoscaling_capacity_providers` | EC2 autoscaling providers | `map(object)` | `{}` |
| **IAM** | | | |
| `create_task_exec_iam_role` | Create task execution role | `bool` | `true` |
| `task_exec_iam_role_policies` | Additional managed policies | `map(string)` | `{}` |
| `task_exec_secret_arns` | Secrets Manager ARNs to access | `list(string)` | `[]` |
| `task_exec_ssm_param_arns` | SSM parameter ARNs to access | `list(string)` | `[]` |
| `task_exec_iam_statements` | Custom IAM statements | `list(object)` | `[]` |
| **Services** | | | |
| `services` | Map of ECS service definitions | `map(object)` | `{}` |
| **Standalone Tasks** | | | |
| `task_definitions` | Map of standalone task definitions | `map(object)` | `{}` |

See [7-variables.tf](ecs/7-variables.tf) for the complete variable reference with all nested attributes.

## Outputs

| Name | Description |
|------|-------------|
| **Cluster** | |
| `cluster_id` | ECS cluster ID |
| `cluster_arn` | ECS cluster ARN |
| `cluster_name` | ECS cluster name |
| `cluster_log_group_name` | Cluster CloudWatch log group name |
| `cluster_log_group_arn` | Cluster CloudWatch log group ARN |
| **Capacity Providers** | |
| `cluster_capacity_providers` | Cluster capacity provider attributes |
| `autoscaling_capacity_providers` | EC2 capacity provider details |
| **IAM** | |
| `task_exec_iam_role_name` | Task execution role name |
| `task_exec_iam_role_arn` | Task execution role ARN |
| `task_exec_iam_role_unique_id` | Task execution role unique ID |
| `task_iam_role_names` | Map of per-service task role names |
| `task_iam_role_arns` | Map of per-service task role ARNs |
| `task_iam_role_unique_ids` | Map of per-service task role unique IDs |
| **Services** | |
| `services` | Map of ECS service attributes |
| `task_definitions` | Map of service task definition attributes (ARN, family, revision) |
| `service_log_groups` | Map of service CloudWatch log group attributes |
| **Standalone Tasks** | |
| `standalone_task_definitions` | Map of standalone task definition attributes |
| `standalone_task_definition_log_groups` | Map of standalone task log group attributes |
| **Auto-scaling** | |
| `autoscaling_targets` | Map of autoscaling target attributes (min/max capacity) |
| `autoscaling_policies` | Map of autoscaling policy attributes (name, type, ARN) |

## Module Structure

```
terraform-aws-ecs/
├── ecs/
│   ├── 0-versions.tf           # Provider version constraints
│   ├── 1-cluster.tf            # Cluster, capacity providers, CloudWatch log group
│   ├── 2-services.tf           # ECS services and service task definitions
│   ├── 2b-task-definitions.tf  # Standalone task definitions
│   ├── 3-autoscaling.tf        # Application Auto Scaling targets, policies, schedules
│   ├── 4-iam.tf                # Task execution role, per-service task roles
│   ├── 5-data.tf               # Data sources (region, identity, partition)
│   ├── 6-locals.tf             # Region prefix, naming, container definition builder
│   ├── 7-variables.tf          # Input variables
│   └── 8-outputs.tf            # Output values
├── examples/
│   ├── basic/                  # Simple Fargate NGINX service
│   └── complete/               # Full-featured multi-service deployment
├── CHANGELOG.md
└── LICENSE
```

## License

MIT
