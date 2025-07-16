#!/bin/bash

# ================================================
# IP update task (runs every 12 minutes via cron)
# ================================================
# Variables for DNS Exit update
HOST="mohamedesmaelsonarqube.work.gd"
API_KEY="$DNS_EXIT_API_KEY"

# Build the curl command
command="curl https://api.dnsexit.com/dns/ud/?apikey=${API_KEY} -d host=${HOST}"

# If /var/log exists, append output to ipupdate.log
if [ -d "/var/log" ]; then
    command="$command >> /var/log/ipupdate.log 2>&1"
fi

# Install cron job if not already present
existing_crontab=$(crontab -l 2>/dev/null || true)
if grep -Fq "$command" <<< "$existing_crontab"; then
    echo "Scheduled IP‑update job already exists in crontab."
else
    echo "Adding IP‑update job to crontab (runs every 12 minutes)..."
    {
        echo "$existing_crontab"
        echo "*/12 * * * * $command"
    } | crontab -
    echo "Cron entry added:"
    crontab -l | grep curl
fi

# ================================================
# The rest of your Apache & Certbot setup
# ================================================
echo
echo "=== Installing Apache, Certbot & curl ==="
apt-get update
apt-get install -y apache2 certbot python3-certbot-apache curl

echo
echo "=== Enabling Apache modules ==="
a2enmod proxy proxy_http proxy_html ssl rewrite

echo
echo "=== Starting Apache for HTTP validation ==="
systemctl start apache2

CONFIG_BASE="https://raw.githubusercontent.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/git-actions-pipeline/apache_configs"
EMAIL="mohamed.2714104@gmail.com"

echo
echo "=== Deploying HTTP vhost and enabling site ==="
curl -fsSL "${CONFIG_BASE}/sonarqube-http.conf" \
  -o /etc/apache2/sites-available/sonarqube-http.conf
a2ensite sonarqube-http.conf

echo
echo "=== Opening firewall ports ==="
if command -v ufw &>/dev/null; then
  ufw allow 80/tcp
  ufw allow 443/tcp
fi

echo
echo "=== Obtaining SSL certificates ==="
# ECDSA
certbot --apache \
  --non-interactive --agree-tos -m "${EMAIL}" \
  --cert-name sonarqube-ecdsa \
  --key-type ecdsa --elliptic-curve secp384r1 \
  -d "${HOST}"
# RSA
certbot --apache \
  --non-interactive --agree-tos -m "${EMAIL}" \
  --cert-name sonarqube-rsa \
  -d "${HOST}"

echo
echo "=== Deploying SSL vhost and enabling site ==="
curl -fsSL "${CONFIG_BASE}/sonarqube-ssl.conf" \
  -o /etc/apache2/sites-available/sonarqube-ssl.conf
a2ensite sonarqube-ssl.conf

echo
echo "=== Restarting Apache ==="
if systemctl is-active --quiet apache2; then
  systemctl restart apache2
else
  systemctl start apache2
fi

echo
echo "🎉✅ setup-apache.sh completed successfully."
