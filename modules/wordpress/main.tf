resource "aws_instance" "wordpress" {
  ami                         = "ami-0082873609b4ff7f6"
  instance_type               = var.instance_type
  iam_instance_profile        = var.iam_instance_profile
  user_data                   = file("${path.module}/user_data.sh")
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [var.security_group_id]
  associate_public_ip_address = true

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
  }
}