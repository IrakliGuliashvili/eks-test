# modules/logging/main.tf
data "aws_caller_identity" "current" {}

# Create CloudWatch Log Group for EKS cluster logs
resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = 30
}

# Create IAM OIDC provider for the cluster (if not already created)
data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

# Create IAM policy for Fluent Bit to write logs to CloudWatch
resource "aws_iam_policy" "fluentbit_cloudwatch" {
  name        = "${var.cluster_name}-fluentbit-cloudwatch"
  description = "Policy for Fluent Bit to write logs to CloudWatch"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# Create IAM role for Fluent Bit service account
#resource "aws_iam_role" "fluentbit" {
resource "aws_iam_role" "fluentbit" {
  name = "${var.cluster_name}-fluentbit-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(data.aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}"
        }
        Condition = {
          StringEquals = {
            "${replace(data.aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:sub": "system:serviceaccount:kube-system:fluentbit"
          }
        }
      }
    ]
  })
}

# Attach CloudWatch policy to Fluent Bit IAM role
resource "aws_iam_role_policy_attachment" "fluentbit_cloudwatch" {
  policy_arn = aws_iam_policy.fluentbit_cloudwatch.arn
  role       = aws_iam_role.fluentbit.name
}