# Basic ECS Fargate example

Creates an ECS cluster with the default Fargate capacity providers and a single NGINX service running in private subnets.

Resources created by the module:

- ECS cluster `ause1-ecs-cluster-<account_name>-<project_name>` and its `/ecs/<cluster_name>` log group
- Task execution IAM role `<cluster_name>-task-exec`
- Task definition and service `ause1-ecs-svc-<account_name>-<project_name>-nginx`, with deployment circuit breaker and rollback

The NGINX container sets `readonly_root_filesystem = false`: the stock image writes to `/var/cache/nginx`, so it cannot start with the module default (`true`).

## Usage

```bash
terraform init
terraform plan \
  -var 'account_name=prod' \
  -var 'project_name=myapp' \
  -var 'private_subnet_ids=["subnet-aaa","subnet-bbb"]' \
  -var 'security_group_ids=["sg-0123456789abcdef0"]'
terraform apply
```

## Inputs

| Name                 | Description                                   | Type           | Default       | Required |
| -------------------- | --------------------------------------------- | -------------- | ------------- | :------: |
| `aws_region`         | AWS region                                    | `string`       | `"us-east-1"` |    no    |
| `account_name`       | Account name for resource naming              | `string`       | n/a           |   yes    |
| `project_name`       | Project name for resource naming              | `string`       | n/a           |   yes    |
| `private_subnet_ids` | List of private subnet IDs for the services   | `list(string)` | n/a           |   yes    |
| `security_group_ids` | List of security group IDs for the services   | `list(string)` | `[]`          |    no    |

## Outputs

| Name           | Description                  |
| -------------- | ---------------------------- |
| `cluster_id`   | ID of the ECS cluster        |
| `cluster_name` | Name of the ECS cluster      |
| `services`     | Map of ECS service attributes |
