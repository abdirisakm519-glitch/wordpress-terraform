output "instance_id" {
  description = "ID of the WordPress EC2 instance"
  value       = module.wordpress.instance_id
}

output "instance_ip" {
  description = "Public IP address of the WordPress EC2 instance"
  value       = module.wordpress.instance_ip
}
