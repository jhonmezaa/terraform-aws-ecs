# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v1.5.0] - 2026-11-17

### Added

- `tags_common` variable (AGENTS convention). The existing `tags` variable is kept for backward compatibility and is merged on top of `tags_common`
- Validation of `account_name` and `project_name` (1-32 characters, `^[a-z0-9-]+$`) and of `task_exec_iam_role_name` (max 64 characters), so invalid values fail at plan time
- `LICENSE` (MIT) file and a `README.md` for each example

### Changed

- Tags are merged as `merge(tags_common, tags, <resource tags>, { Name, ManagedBy = "Terraform" })`: `ManagedBy` can no longer be overridden by `tags_common`, `tags` or per-resource tags
- The autoscaling target now gets a `Name` tag (the service name)
- README: `source` examples use `github.com/jhonmezaa/terraform-aws-ecs//ecs?ref=v1.5.0`, the inputs table lists every variable, and the real task execution role / capacity provider / log group names are documented

### Fixed

- Generated IAM role names (`<cluster_name>-task-exec` and `<prefix>iam-role-<account>-<project>-<key>-task`) longer than the 64-character IAM limit failed at apply time; they are now shortened to 55 characters plus an 8-character hash suffix. Names within the limit are unchanged
- EC2 capacity provider names starting with `aws`, `ecs` or `fargate` (for example with `use_region_prefix = false`, where the cluster name starts with `ecs-`) were rejected by AWS; they now get a `cp-` prefix. Other names are unchanged
- `complete` example: invalid scheduled action cron expressions (`?` is required in day-of-month or day-of-week), ECS Exec logging pointed at a log group that was never created, services with `enable_execute_command` had no task role, `target_group_arn` / `db_secret_arn` defaulted to `""` (invalid ARNs), and the header comment listed features the example does not use
- `basic` example and README usage: the stock `nginx` image cannot start with the module default `readonly_root_filesystem = true`; the examples set it to `false`
- README: invalid managed policy ARN in the task role example (`arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess`)

### Upgrade notes

- `account_name` / `project_name` with uppercase letters, underscores or more than 32 characters now fail validation. Those values were already used verbatim in resource names; rename them (this renames and replaces the resources) or pin `v1.4.5`
- If you set a `ManagedBy` tag through `tags`, `cloudwatch_log_group_tags`, `task_exec_iam_role_tags` or a per-service / per-task `tags` map, it is now replaced by `ManagedBy = "Terraform"` (tag-only in-place update)
- No resource is renamed for configurations that worked with v1.4.5: the IAM role and capacity provider name changes only affect names that AWS rejected before

## [v1.4.5] - 2026-10-27

### Changed

- Docs: normalize CHANGELOG format (preamble moved to the top, `v`-prefixed version headers, link references updated)
- Docs: add missing CHANGELOG entry for v1.4.1

## [v1.4.4] - 2026-10-27

### Fixed

- Replace deprecated `data.aws_region.current.id` with `data.aws_region.current.region` (deprecated in AWS provider v6)

## [v1.4.3] - 2026-10-27

### Changed

- Use minimum-only version constraints in the reusable module: AWS provider `~> 6.0` -> `>= 6.0`
- Set module `required_version` to `>= 1.3` (was `~> 1.0`): the module uses `optional()` object type attributes, introduced in Terraform 1.3
- Example root modules keep pessimistic `~>` constraints (AWS provider `~> 6.0`, Terraform `~> 1.3`)
- Update requirements in README accordingly

## [v1.4.2] - 2026-04-25

### Changed

- Update README documentation and CHANGELOG formatting

## [v1.4.1] - 2026-02-28

### Changed

- Add comprehensive README.md
- Update CHANGELOG

## [v1.4.0] - 2026-02-28

### Added

- Per-service task IAM role creation via `create_task_role` boolean on services, with `AmazonSSMManagedInstanceCore` policy attached for `enable_execute_command` support
- `task_role_policy_arns` map on services for attaching additional managed policies to task roles
- Task role naming follows convention: `{region_prefix}-iam-role-{account_name}-{project_name}-{service_key}-task`
- New outputs: `task_iam_role_names`, `task_iam_role_arns`, `task_iam_role_unique_ids`
- `awsfirelens` log driver support in container definitions: when `log_driver = "awsfirelens"`, log configuration options are passed through as-is (e.g., Fluentbit Name, Host, Port) instead of defaulting to awslogs options

## [v1.3.0] - 2026-02-27

### Added

- `use_region_prefix` boolean variable (default: `true`) to control whether the region prefix is included in resource names. When `false`, names omit the prefix

## [v1.2.1] - 2026-02-27

### Changed

- Standardize Terraform `required_version` to `~> 1.0` across module and examples

## [v1.2.0] - 2026-02-27

### Changed

- Update AWS provider constraint to `~> 6.0` across module and examples

## [v1.1.0] - 2026-02-27

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

## [v1.0.0] - 2026-02-27

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

[v1.1.0]: https://github.com/jhonmezaa/terraform-aws-ecs/releases/tag/v1.1.0
[v1.0.0]: https://github.com/jhonmezaa/terraform-aws-ecs/releases/tag/v1.0.0
