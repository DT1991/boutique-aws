output "build_role_arn" {
  description = "Set as AWS_ROLE_ARN_BUILD in GitHub Secrets"
  value       = aws_iam_role.build.arn
}

output "deploy_role_arn" {
  description = "Set as AWS_ROLE_ARN_DEV / TEST / PERF / STAGING / PROD in GitHub Secrets (single account)"
  value       = aws_iam_role.deploy.arn
}

output "github_secrets_setup" {
  description = "GitHub Secrets to configure"
  value = {
    AWS_ACCOUNT_ID     = data.aws_caller_identity.current.account_id
    AWS_ROLE_ARN_BUILD = aws_iam_role.build.arn
    AWS_ROLE_ARN_DEV   = aws_iam_role.deploy.arn
    AWS_ROLE_ARN_TEST  = aws_iam_role.deploy.arn
    AWS_ROLE_ARN_PERF  = aws_iam_role.deploy.arn
    AWS_ROLE_ARN_STAGING = aws_iam_role.deploy.arn
    AWS_ROLE_ARN_PROD  = aws_iam_role.deploy.arn
  }
}
