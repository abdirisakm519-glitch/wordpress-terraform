resource "aws_secretsmanager_secret" "wordpress_db" {
  name = "wordpress-db-password"
}
