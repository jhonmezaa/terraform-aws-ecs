output "cluster_id" {
  description = "ID of the ECS cluster"
  value       = module.ecs.cluster_id
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs.cluster_name
}

output "cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = module.ecs.cluster_arn
}

output "services" {
  description = "Map of ECS service attributes"
  value       = module.ecs.services
}

output "task_definitions" {
  description = "Map of task definition attributes"
  value       = module.ecs.task_definitions
}

output "task_exec_role_arn" {
  description = "ARN of the task execution IAM role"
  value       = module.ecs.task_exec_iam_role_arn
}

output "autoscaling_targets" {
  description = "Map of autoscaling target attributes"
  value       = module.ecs.autoscaling_targets
}
