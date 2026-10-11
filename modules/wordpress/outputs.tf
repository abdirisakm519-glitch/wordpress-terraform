output "instance_id" {
  description = "ID of the WordPress EC2 instance"
  value       = aws_instance.wordpress.id
}

output "instance_ip" {
  description = "Public IP address of the WordPress EC2 instance"
  value       = aws_instance.wordpress.public_ip
}
