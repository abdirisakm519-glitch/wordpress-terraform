variable "instance_type" {
  description = "EC2 instance type for WordPress"
  type        = string
  default     = "t3.micro"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-2"
}

variable "iam_instance_profile" {
  description = "IAM instance profile attached to the WordPress EC2 instance"
  type        = string
}

variable "subnet_id" {
  description = "Subnet where the WordPress EC2 instance will run"
  type        = string
}

variable "security_group_id" {
  description = "Security group attached to the WordPress EC2 instance"
  type        = string
}