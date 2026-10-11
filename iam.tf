resource "aws_iam_role" "wordpress" {
  name = "wordpress-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "wordpress" {
  name = "wordpress-secret-access"
  role = aws_iam_role.wordpress.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue"
        ]

        Effect   = "Allow"
        Resource = aws_secretsmanager_secret.wordpress_db.arn
      }
    ]
  })
}

resource "aws_iam_instance_profile" "wordpress" {
  name = "wordpress-ec2-profile"
  role = aws_iam_role.wordpress.name
}