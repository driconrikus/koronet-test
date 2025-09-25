variable "docker_username" {
  description = "Your Docker Hub username"
  type        = string
}

variable "db_host" {
  description = "Database host"
  type        = string
  default     = "db"
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "koronet_db"
}

variable "db_user" {
  description = "Database user"
  type        = string
  default     = "koronet_user"
}

variable "db_password" {
  description = "Database password"
  type        = string
  default     = "koronet_password"
}

variable "redis_host" {
  description = "Redis host"
  type        = string
  default     = "redis"
}

variable "redis_port" {
  description = "Redis port"
  type        = number
  default     = 6379
}

variable "grafana_admin_user" {
  description = "Grafana admin username"
  type        = string
  sensitive   = true
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
}
