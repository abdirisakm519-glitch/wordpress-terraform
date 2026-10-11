# Assignment 1 - Deploy WordPress Using Terraform
#
# This project provisions a WordPress server on AWS.
#
# Infrastructure resources are organised into separate files:
# - provider.tf: AWS provider configuration
# - ec2.tf: WordPress EC2 instance
# - vpc.tf, subnet.tf, route.tf: Networking
# - security_group.tf: Security groups
# - iam.tf: IAM roles and permissions
# - secrets.tf: AWS Secrets Manager
#
# Terraform automatically loads all .tf files in this directory.
module "wordpress" {
  source = "./modules/wordpress"

  instance_type        = var.instance_type
  iam_instance_profile = aws_iam_instance_profile.wordpress.name
  subnet_id            = aws_subnet.public.id
  security_group_id    = aws_security_group.allow.id
}

moved {
  from = aws_instance.wordpress
  to   = module.wordpress.aws_instance.wordpress
}
