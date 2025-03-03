# modules/monitoring/main.tf
data "aws_caller_identity" "current" {}

# Get EKS cluster details
data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

# Create IAM policy for CloudWatch metrics
resource "aws_iam_policy" "cloudwatch_metrics" {
  name        = "${var.cluster_name}-cloudwatch-metrics"
  description = "Policy for CloudWatch metrics collection from EKS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "cloudwatch:PutMetricData",
          "ec2:DescribeVolumes",
          "ec2:DescribeTags"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}


# Create IAM role for CloudWatch metrics service account
resource "aws_iam_role" "cloudwatch_metrics" {
  name = "${var.cluster_name}-cloudwatch-metrics-role"

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
            "${replace(data.aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:sub": "system:serviceaccount:amazon-cloudwatch:cloudwatch-agent"
          }
        }
      }
    ]
  })
}

# Attach CloudWatch metrics policy to IAM role
resource "aws_iam_role_policy_attachment" "cloudwatch_metrics" {
  policy_arn = aws_iam_policy.cloudwatch_metrics.arn
  role       = aws_iam_role.cloudwatch_metrics.name
}