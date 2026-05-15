kubernetes_version         = "1.35"
availability_zones         = ["ap-northeast-1a", "ap-northeast-1c"]
vpc_cidr                   = "10.10.0.0/16"
single_nat_gateway         = true
flow_log_retention_days    = 7
endpoint_public_access     = true

system_node_instance_types = ["t3.medium"]
system_node_desired        = 1
system_node_min            = 1
system_node_max            = 2

app_node_instance_types    = ["t3.medium"]
app_node_desired           = 2
app_node_min               = 1
app_node_max               = 5

redis_node_type                = "cache.t3.micro"
redis_num_cache_nodes          = 1
redis_snapshot_retention_days  = 0

s3_force_destroy           = true


