# modules/fargate-profiles/outputs.tf

output "test_app_fargate_profile_arn" {
  description = "ARN of the test-app Fargate profile"
  value       = aws_eks_fargate_profile.test_app.arn
}

output "kube_system_fargate_profile_arn" {
  description = "ARN of the kube-system Fargate profile"
  value       = aws_eks_fargate_profile.kube_system.arn
}