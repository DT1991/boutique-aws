# Primary region: ap-northeast-1 (Tokyo)
availability_zones         = ["ap-northeast-1a", "ap-northeast-1c", "ap-northeast-1d"]
vpc_cidr                   = "10.0.0.0/16"
single_nat_gateway         = false
flow_log_retention_days    = 90
endpoint_public_access     = false

system_node_instance_types = ["m5.large"]
system_node_desired        = 3
system_node_min            = 3
system_node_max            = 6

app_node_instance_types    = ["m5.xlarge", "m5.2xlarge"]
app_node_desired           = 6
app_node_min               = 3
app_node_max               = 50

redis_node_type                = "cache.r6g.large"
redis_num_cache_nodes          = 3
redis_snapshot_retention_days  = 7

s3_log_retention_days      = 90

# Secondary region: us-east-1 (Virginia) — active-active, full production capacity
secondary_region               = "us-east-1"
secondary_vpc_cidr             = "10.1.0.0/16"
secondary_availability_zones   = ["us-east-1a", "us-east-1b", "us-east-1c"]
secondary_system_node_desired  = 3
secondary_system_node_min      = 3
secondary_system_node_max      = 6
secondary_app_node_desired     = 6
secondary_app_node_min         = 3
secondary_app_node_max         = 50
