# ==============================================================================
# TASK EXECUTION IAM ROLE
# ==============================================================================

data "aws_iam_policy_document" "task_exec_assume" {
  count = var.create_task_exec_iam_role ? 1 : 0

  statement {
    sid     = "ECSTaskExecutionAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    # Confused deputy protection
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:${local.partition}:ecs:${data.aws_region.current.id}:${local.account_id}:*"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}

resource "aws_iam_role" "task_exec" {
  count = var.create_task_exec_iam_role ? 1 : 0

  name                 = coalesce(var.task_exec_iam_role_name, "${local.cluster_name}-task-exec")
  path                 = var.task_exec_iam_role_path
  description          = var.task_exec_iam_role_description
  assume_role_policy   = data.aws_iam_policy_document.task_exec_assume[0].json
  permissions_boundary = var.task_exec_iam_role_permissions_boundary

  tags = merge(
    local.tags_common,
    var.task_exec_iam_role_tags,
    {
      Name = coalesce(var.task_exec_iam_role_name, "${local.cluster_name}-task-exec")
    }
  )
}

# Attach the AWS managed ECS Task Execution policy
resource "aws_iam_role_policy_attachment" "task_exec_base" {
  count = var.create_task_exec_iam_role ? 1 : 0

  role       = aws_iam_role.task_exec[0].name
  policy_arn = "arn:${local.partition}:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Additional managed policies
resource "aws_iam_role_policy_attachment" "task_exec_additional" {
  for_each = { for k, v in var.task_exec_iam_role_policies : k => v if var.create_task_exec_iam_role }

  role       = aws_iam_role.task_exec[0].name
  policy_arn = each.value
}

# Inline policy for secrets, SSM parameters, and custom statements
data "aws_iam_policy_document" "task_exec_inline" {
  count = var.create_task_exec_iam_role && (length(var.task_exec_secret_arns) > 0 || length(var.task_exec_ssm_param_arns) > 0 || length(var.task_exec_iam_statements) > 0) ? 1 : 0

  # Secrets Manager access
  dynamic "statement" {
    for_each = length(var.task_exec_secret_arns) > 0 ? [1] : []
    content {
      sid       = "GetSecrets"
      effect    = "Allow"
      actions   = ["secretsmanager:GetSecretValue"]
      resources = var.task_exec_secret_arns
    }
  }

  # SSM Parameter Store access
  dynamic "statement" {
    for_each = length(var.task_exec_ssm_param_arns) > 0 ? [1] : []
    content {
      sid       = "GetSSMParams"
      effect    = "Allow"
      actions   = ["ssm:GetParameters"]
      resources = var.task_exec_ssm_param_arns
    }
  }

  # Custom statements
  dynamic "statement" {
    for_each = var.task_exec_iam_statements
    content {
      sid       = statement.value.sid
      effect    = statement.value.effect
      actions   = statement.value.actions
      resources = statement.value.resources

      dynamic "condition" {
        for_each = statement.value.conditions
        content {
          test     = condition.value.test
          variable = condition.value.variable
          values   = condition.value.values
        }
      }
    }
  }
}

resource "aws_iam_role_policy" "task_exec" {
  count = var.create_task_exec_iam_role && (length(var.task_exec_secret_arns) > 0 || length(var.task_exec_ssm_param_arns) > 0 || length(var.task_exec_iam_statements) > 0) ? 1 : 0

  name   = "${local.cluster_name}-task-exec-inline"
  role   = aws_iam_role.task_exec[0].id
  policy = data.aws_iam_policy_document.task_exec_inline[0].json
}
