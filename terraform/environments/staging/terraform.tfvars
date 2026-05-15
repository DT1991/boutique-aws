# Primary region: ap-northeast-1 (Tokyo)
availability_zones         = ["ap-northeast-1a", "ap-northeast-1c", "ap-northeast-1d"]
vpc_cidr                   = "10.13.0.0/16"
single_nat_gateway         = false
flow_log_retention_days    = 30
endpoint_public_access     = false

system_node_instance_types = ["t3.large"]
system_node_desired        = 2
system_node_min            = 2
system_node_max            = 4

app_node_instance_types    = ["m5.large"]
app_node_desired           = 3
app_node_min               = 2
app_node_max               = 10

redis_node_type                = "cache.r6g.large"
redis_num_cache_nodes          = 2
redis_snapshot_retention_days  = 3

s3_log_retention_days      = 60

# Secondary region: us-east-1 (Virginia) — DR, reduced capacity
secondary_region               = "us-east-1"
secondary_vpc_cidr             = "10.15.0.0/16"
secondary_availability_zones   = ["us-east-1a", "us-east-1b", "us-east-1c"]
secondary_system_node_desired  = 2
secondary_system_node_min      = 2
secondary_system_node_max      = 4
secondary_app_node_desired     = 2
secondary_app_node_min         = 2
secondary_app_node_max         = 8
