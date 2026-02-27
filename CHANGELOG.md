# Changelog

## [v1.2.1] - 2026-02-27

### Changed
- Standardize Terraform `required_version` to `~> 1.0` across module and examples


## [v1.2.0] - 2026-02-27

### Changed
- Update AWS provider constraint to `~> 6.0` across module and examples


All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-02-27

### Added

#### Standalone Task Definitions
- New `task_definitions` variable for creating task definitions without an ECS service
- Useful for `RunTask` invocations, EventBridge scheduled tasks, cron jobs, and one-off tasks
- Same container definition features as service-based task definitions
- Per-task CloudWatch log groups with configurable retention and KMS
- Volume support (host, Docker, EFS)
- Runtime platform, ephemeral storage, proxy configuration
- New outputs: `standalone_task_definitions`, `standalone_task_definition_log_groups`
- Shared container definition builder in locals (avoids code duplication)

## [1.0.0] - 2026-02-27

### Added

#### ECS Cluster
- ECS cluster with configurable settings (containerInsights enhanced by default)
- Execute command configuration with CloudWatch and S3 logging
- Service Connect defaults namespace support
- Cluster-level CloudWatch log group with configurable retention and KMS encryption

#### Capacity Providers
- Fargate and Fargate Spot capacity providers with default strategy
- EC2 autoscaling capacity providers with managed scaling and termination protection
- Managed draining support for EC2 capacity providers

#### ECS Services
- Multiple services via `for_each` pattern on `services` map
- Dual service resource pattern (standard vs `ignore_task_definition_changes`)
- Network configuration (awsvpc mode) with subnet, security group, and public IP support
- Capacity provider strategy per service
- Deployment circuit breaker with rollback
- Deployment alarms integration
- Load balancer target group integration
- Service registries (AWS Cloud Map) integration
- Service Connect with TLS, timeouts, and log configuration
- Ordered placement strategy (EC2 launch type)
- Placement constraints
- EBS volume configuration with managed volumes
- VPC Lattice integration
- Configurable timeouts (create, update, delete)
- Force new deployment support

#### Task Definitions
- Container definitions built from typed variable (no external JSON)
- Runtime platform (Linux/Windows, X86_64/ARM64)
- Ephemeral storage configuration
- Proxy configuration (App Mesh)
- Volume support: host path, Docker volumes, EFS volumes
- Create before destroy lifecycle

#### Container Definitions
- Full container definition builder via locals (no submodule needed)
- Port mappings with app_protocol for Service Connect
- Environment variables and environment files (S3)
- Secrets Manager and SSM Parameter Store secrets
- Health checks with configurable intervals
- CloudWatch Logs integration (awslogs driver, auto-configured)
- Mount points and volumes from other containers
- Container dependencies with conditions
- Linux parameters (capabilities, init process)
- FireLens logging configuration
- Docker labels, ulimits, resource requirements
- System controls, extra hosts
- Read-only root filesystem (enabled by default)

#### Auto-scaling
- Application Auto Scaling target per service
- Target tracking scaling policies (CPU, Memory, custom metrics)
- Scheduled scaling actions with timezone support
- Customized metric specifications with math expressions

#### IAM
- Task execution IAM role with confused deputy protection
- AWS managed `AmazonECSTaskExecutionRolePolicy` attachment
- Inline policy for Secrets Manager and SSM Parameter Store access
- Additional managed policy attachments
- Custom IAM statements support
- Permissions boundary support

#### Naming Convention
- Region prefix auto-generation from 29 AWS regions
- Pattern: `{region_prefix}-ecs-{resource}-{account_name}-{project_name}[-{suffix}]`
- Common tags applied to all resources

#### Examples
- Basic Fargate example
- Complete example with all features

[1.1.0]: https://github.com/jhonmezaa/terraform-aws-ecs/releases/tag/v1.1.0
[1.0.0]: https://github.com/jhonmezaa/terraform-aws-ecs/releases/tag/v1.0.0
