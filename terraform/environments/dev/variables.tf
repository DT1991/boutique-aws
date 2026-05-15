variable "kubernetes_version" { type = string }
variable "availability_zones" { type = list(string) }
variable "vpc_cidr" { type = string }
variable "single_nat_gateway" { type = bool }
variable "flow_log_retention_days" { type = number }
variable "endpoint_public_access" { type = bool }
variable "system_node_instance_types" { type = list(string) }
variable "system_node_desired" { type = number }
variable "system_node_min" { type = number }
variable "system_node_max" { type = number }
variable "app_node_instance_types" { type = list(string) }
variable "app_node_desired" { type = number }
variable "app_node_min" { type = number }
variable "app_node_max" { type = number }
variable "redis_node_type" { type = string }
variable "redis_num_cache_nodes" { type = number }
variable "redis_snapshot_retention_days" { type = number }
variable "s3_force_destroy" { type = bool }

variable "developer_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}
