output "eks_cluster_name"          { value = module.eks.cluster_name }
output "kubeconfig_cmd"            { value = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ap-northeast-1" }
output "redis_endpoint"            { value = module.redis.primary_endpoint }
output "alb_controller_role_arn"   { value = module.eks.alb_controller_role_arn }
output "external_secrets_role_arn" { value = module.eks.external_secrets_role_arn }
