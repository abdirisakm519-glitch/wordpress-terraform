
#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

# Log installation output for troubleshooting
exec > >(tee -a /var/log/wordpress-install.log) 2>&1

echo "Starting WordPress installation..."

# Install required tools
apt-get update -y
apt-get install -y \
  awscli \
  curl \
  wget \
  python3 \
  ca-certificates \
  apache2 \
  mariadb-server \
  php \
  libapache2-mod-php \
  php-mysql \
  php-curl \
  php-gd \
  php-mbstring \
  php-xml \
  php-zip

# Retrieve database password from AWS Secrets Manager
DB_PASSWORD="$(aws secretsmanager get-secret-value \
  --region eu-west-2 \
  --secret-id wordpress-db-password \
  --query SecretString \
  --output text)"

if [[ -z "$DB_PASSWORD" || "$DB_PASSWORD" == "None" ]]; then
  echo "ERROR: Database password is missing"
  exit 1
fi

# Prevent newline characters in the database password
if [[ "$DB_PASSWORD" == *$'\n'* || "$DB_PASSWORD" == *$'\r'* ]]; then
  echo "ERROR: Database password contains a newline character"
  exit 1
fi

# Create database and user safely using Python to escape SQL strings
export DB_PASSWORD

python3 - <<'PY' > /tmp/wordpress-db-setup.sql
import os

password = os.environ["DB_PASSWORD"]

# Escape backslashes and single quotes for MariaDB SQL strings.
# The generated SQL uses NO_BACKSLASH_ESCAPES so backslashes
# are treated literally, and single quotes are doubled.
password_sql = password.replace("'", "''")

print("SET SESSION sql_mode = 'NO_BACKSLASH_ESCAPES';")
print("CREATE DATABASE IF NOT EXISTS wordpress;")
print("CREATE USER IF NOT EXISTS 'wordpress_user'@'localhost' IDENTIFIED BY '" + password_sql + "';")
print("ALTER USER 'wordpress_user'@'localhost' IDENTIFIED BY '" + password_sql + "';")
print("GRANT ALL PRIVILEGES ON wordpress.* TO 'wordpress_user'@'localhost';")
print("FLUSH PRIVILEGES;")
PY

systemctl enable mariadb
systemctl start mariadb

mariadb < /tmp/wordpress-db-setup.sql
rm -f /tmp/wordpress-db-setup.sql

# Download and install WordPress
cd /tmp
wget -q https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz

rm -f /var/www/html/index.html
cp -a /tmp/wordpress/. /var/www/html/

# Generate wp-config.php safely without sed password substitution
cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php

python3 - <<'PY'
import os
import re
from pathlib import Path

config_path = Path("/var/www/html/wp-config.php")
config = config_path.read_text()
password = os.environ["DB_PASSWORD"]

def php_string(value):
    # Escape characters for a PHP single-quoted string.
    return "'" + value.replace("\\", "\\\\").replace("'", "\\'") + "'"

settings = {
    "DB_NAME": "wordpress",
    "DB_USER": "wordpress_user",
    "DB_PASSWORD": password,
    "DB_HOST": "localhost",
}

for key, value in settings.items():
    pattern = r"define\(\s*['\"]" + re.escape(key) + r"['\"]\s*,\s*.*?\);"
    replacement = "define( " + php_string(key) + ", " + php_string(value) + " );"
    config, count = re.subn(
        pattern,
        lambda match: replacement,
        config,
        count=1
    )
    if count != 1:
        raise RuntimeError("Could not update " + key)

config_path.write_text(config)
PY

# Generate secure WordPress authentication salts
curl -fsSL https://api.wordpress.org/secret-key/1.1/salt/ \
  -o /tmp/wordpress-salts.txt

python3 - <<'PY'
import re
from pathlib import Path

config_path = Path("/var/www/html/wp-config.php")
config = config_path.read_text()
salts = Path("/tmp/wordpress-salts.txt").read_text().strip()

keys = [
    "AUTH_KEY",
    "SECURE_AUTH_KEY",
    "LOGGED_IN_KEY",
    "NONCE_KEY",
    "AUTH_SALT",
    "SECURE_AUTH_SALT",
    "LOGGED_IN_SALT",
    "NONCE_SALT",
]

for key in keys:
    pattern = r"define\(\s*['\"]" + re.escape(key) + r"['\"]\s*,\s*.*?\);"
    salt_line = next(
        (line for line in salts.splitlines()
         if re.match(r"define\(\s*['\"]" + re.escape(key) + r"['\"]", line)),
        None
    )

    if salt_line is None:
        raise RuntimeError("Missing WordPress salt: " + key)

    config, count = re.subn(
        pattern,
        lambda match: salt_line,
        config,
        count=1
    )

    if count != 1:
        raise RuntimeError("Could not update WordPress salt: " + key)

config_path.write_text(config)
PY

rm -f /tmp/wordpress-salts.txt

# Set file permissions
chown -R www-data:www-data /var/www/html
find /var/www/html -type d -exec chmod 755 {} \;
find /var/www/html -type f -exec chmod 644 {} \;
chmod 640 /var/www/html/wp-config.php

# Start Apache
systemctl enable apache2
systemctl restart apache2

# Avoid leaving the password in the environment
unset DB_PASSWORD

echo "WordPress installation completed successfully!"
