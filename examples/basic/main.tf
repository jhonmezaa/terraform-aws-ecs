# ==============================================================================
# BASIC ECS FARGATE EXAMPLE
# ==============================================================================
# Creates an ECS cluster with Fargate and a single NGINX service

module "ecs" {
  source = "../../ecs"

  account_name = var.account_name
  project_name = var.project_name

  # Cluster configuration
  cluster_settings = [
    {
      name  = "containerInsights"
      value = "enabled"
    }
  ]

  # Use default Fargate capacity providers
  default_capacity_provider_use_fargate = true

  # Services
  services = {
    nginx = {
      cpu    = 256
      memory = 512

      containers = {
        nginx = {
          image     = "nginx:latest"
          essential = true

          port_mappings = [
            {
              container_port = 80
              protocol       = "tcp"
              name           = "http"
            }
          ]

          environment = [
            {
              name  = "ENV"
              value = "production"
            }
          ]
        }
      }

      # Network
      subnet_ids         = var.private_subnet_ids
      security_group_ids = var.security_group_ids

      # Deployment
      desired_count = 2
      deployment_circuit_breaker = {
        enable   = true
        rollback = true
      }
    }
  }

  tags = {
    Environment = "production"
    Example     = "basic"
  }
}
