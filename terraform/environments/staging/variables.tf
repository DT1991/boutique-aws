variable "kubernetes_version" {
  type    = string
  default = "1.34"
}
variable "availability_zones"            { type = list(string) }
variable "vpc_cidr"                      { type = string }
variable "single_nat_gateway"            { type = bool }
variable "flow_log_retention_days"       { type = number }
variable "endpoint_public_access"        { type = bool }
variable "system_node_instance_types"    { type = list(string) }
variable "system_node_desired"           { type = number }
variable "system_node_min"               { type = number }
variable "system_node_max"               { type = number }
variable "app_node_instance_types"       { type = list(string) }
variable "app_node_desired"              { type = number }
variable "app_node_min"                  { type = number }
variable "app_node_max"                  { type = number }
variable "redis_node_type"               { type = string }
variable "redis_num_cache_nodes"         { type = number }
variable "redis_snapshot_retention_days" { type = number }
variable "s3_log_retention_days"         { type = number }

# Secondary region (DR)
variable "secondary_region"              { type = string }
variable "secondary_vpc_cidr"            { type = string }
variable "secondary_availability_zones"  { type = list(string) }
variable "secondary_system_node_desired" { type = number }
variable "secondary_system_node_min"     { type = number }
variable "secondary_system_node_max"     { type = number }
variable "secondary_app_node_desired"    { type = number }
variable "secondary_app_node_min"        { type = number }
variable "secondary_app_node_max"        { type = number }
