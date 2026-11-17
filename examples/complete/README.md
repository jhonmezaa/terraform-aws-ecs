# Complete ECS example

Creates an ECS cluster with two Fargate services (`api` and `worker`) showing most of the module features:

- Enhanced Container Insights and ECS Exec with session logs sent to a CloudWatch log group created in this example
- `FARGATE` / `FARGATE_SPOT` default capacity provider strategy
- Task execution role with access to a Secrets Manager secret (`task_exec_secret_arns`)
- Per-service task roles (`create_task_role = true`), required for `enable_execute_command`
- `api`: ALB target group attachment, health check, sidecar container, CPU/memory target tracking and scheduled scaling actions
- `worker`: background worker with CPU target tracking

## Usage

```bash
terraform init
terraform plan \
  -var 'account_name=prod' \
  -var 'project_name=platform' \
  -var 'private_subnet_ids=["subnet-aaa","subnet-bbb"]' \
  -var 'security_group_ids=["sg-0123456789abcdef0"]' \
  -var 'target_group_arn=arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/api/0123456789abcdef' \
  -var 'db_secret_arn=arn:aws:secretsmanager:us-east-1:123456789012:secret:db-AbCdEf'
terraform apply
```

## Inputs

| Name                 | Description                                                 | Type           | Default       | Required |
| -------------------- | ----------------------------------------------------------- | -------------- | ------------- | :------: |
| `aws_region`         | AWS region                                                  | `string`       | `"us-east-1"` |    no    |
| `account_name`       | Account name for resource naming                            | `string`       | n/a           |   yes    |
| `project_name`       | Project name for resource naming                            | `string`       | n/a           |   yes    |
| `private_subnet_ids` | List of private subnet IDs for the services                 | `list(string)` | n/a           |   yes    |
| `security_group_ids` | List of security group IDs for the services                 | `list(string)` | `[]`          |    no    |
| `target_group_arn`   | ARN of the ALB target group for the API service             | `string`       | n/a           |   yes    |
| `db_secret_arn`      | ARN of the Secrets Manager secret for database credentials  | `string`       | n/a           |   yes    |

## Outputs

| Name                  | Description                          |
| --------------------- | ------------------------------------ |
| `cluster_id`          | ID of the ECS cluster                |
| `cluster_name`        | Name of the ECS cluster              |
| `cluster_arn`         | ARN of the ECS cluster               |
| `services`            | Map of ECS service attributes        |
| `task_definitions`    | Map of task definition attributes    |
| `task_exec_role_arn`  | ARN of the task execution IAM role   |
| `autoscaling_targets` | Map of autoscaling target attributes |
