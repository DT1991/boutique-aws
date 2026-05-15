# Primary region
output "primary_eks_cluster_name" {
  value = module.eks.cluster_name
}
output "primary_kubeconfig_cmd" {
  value = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ap-northeast-1"
}
output "primary_redis_endpoint" {
  value = module.redis.primary_endpoint
}
output "primary_alb_controller_role_arn" {
  value = module.eks.alb_controller_role_arn
}
output "primary_external_secrets_role_arn" {
  value = module.eks.external_secrets_role_arn
}
output "ecr_urls" {
  value = module.ecr.repository_urls
}

# Secondary region (DR / active-active)
output "secondary_eks_cluster_name" {
  value = module.eks_secondary.cluster_name
}
output "secondary_kubeconfig_cmd" {
  value = "aws eks update-kubeconfig --name ${module.eks_secondary.cluster_name} --region ${var.secondary_region}"
}
output "secondary_redis_endpoint" {
  value = module.redis_secondary.primary_endpoint
}
output "secondary_alb_controller_role_arn" {
  value = module.eks_secondary.alb_controller_role_arn
}
output "secondary_external_secrets_role_arn" {
  value = module.eks_secondary.external_secrets_role_arn
}
output "secondary_alb_logs_bucket" {
  value = module.s3_secondary.alb_logs_bucket_id
}
