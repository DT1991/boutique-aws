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

# Secondary region (DR)
output "secondary_eks_cluster_name" {
  value = module.eks_secondary.cluster_name
}
output "secondary_kubeconfig_cmd" {
  value = "aws eks update-kubeconfig --name ${module.eks_secondary.cluster_name} --region ${var.secondary_region}"
}
output "secondary_redis_endpoint" {
  value = module.redis_secondary.primary_endpoint
}
output "secondary_alb_logs_bucket" {
  value = module.s3_secondary.alb_logs_bucket_id
}
