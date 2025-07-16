#!/usr/bin/env bash
set -euo pipefail

echo
echo "=== Adding Dynamic DNS update job to crontab ==="

if [[ -z "${DNS_EXIT_API_KEY:-}" ]]; then
  echo "❌ Error: DNS_EXIT_API_KEY environment variable not set"
  exit 1
fi

LOGFILE="/var/log/ipupdate.log"
HOST="mohamedesmaelsonarqube.work.gd"
API_KEY="$DNS_EXIT_API_KEY"

# Build the curl command
command="curl -s https://api.dnsexit.com/dns/ud/?apikey=${API_KEY} -d host=${HOST}"
if [ -d "/var/log" ]; then
  command="$command >> ${LOGFILE} 2>&1"
fi

# Get the existing crontab content (empty if none)
existing_crontab=$(crontab -l 2>/dev/null || true)

# Check if the command is already in crontab
if [[ $existing_crontab == *"$command"* ]]; then
  echo "Scheduled job already exists in crontab."
else
  # Build the new crontab content without leading blank lines
  if [[ -z "$existing_crontab" ]]; then
    new_crontab="*/12 * * * * $command"
  else
    new_crontab="${existing_crontab}"$'\n'"*/12 * * * * $command"
  fi

  # Install the modified crontab
  printf "%s\n" "$new_crontab" | crontab -
  echo "The following job has been added to crontab. Use 'crontab -l' to view:"
  crontab -l | grep curl
fi

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
