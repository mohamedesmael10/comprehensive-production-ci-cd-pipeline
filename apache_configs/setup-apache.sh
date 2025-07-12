#!/usr/bin/env bash
set -euo pipefail

echo "=== Updating system and installing Apache & Certbot ==="
sudo apt-get update
sudo apt-get install -y apache2 certbot python3-certbot-apache curl

echo ""
echo "=== Enabling Apache modules ==="
sudo a2enmod proxy proxy_http proxy_html ssl

echo ""
echo "=== Starting Apache temporarily for HTTP (needed for certbot) ==="
sudo systemctl start apache2

CONFIG_BASE="https://raw.githubusercontent.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/git-actions-pipeline/apache_configs"

echo ""
echo "=== Downloading and enabling Apache site configs ==="
sudo curl -fsSL "$CONFIG_BASE/jenkins.conf"   -o /etc/apache2/sites-available/jenkins.conf
sudo curl -fsSL "$CONFIG_BASE/sonarqube.conf" -o /etc/apache2/sites-available/sonarqube.conf

sudo a2ensite jenkins.conf
sudo a2ensite sonarqube.conf

if command -v ufw >/dev/null 2>&1; then
  echo ""
  echo "=== Configuring UFW firewall ==="
  sudo ufw allow 80/tcp
  sudo ufw allow 443/tcp
fi

echo ""
echo "=== Obtaining SSL certificates (RSA and ECDSA) ==="
EMAIL="mohamed.2714104@gmail.com"

# ECDSA certs
sudo certbot --apache -d mohamedesmael.work.gd \
  --cert-name mohamedesmael-ecdsa --key-type ecdsa --elliptic-curve secp384r1 --non-interactive --agree-tos -m "$EMAIL"

sudo certbot --apache -d mohamedesmaelsonarqube.work.gd \
  --cert-name sonarqube-ecdsa --key-type ecdsa --elliptic-curve secp384r1 --non-interactive --agree-tos -m "$EMAIL"

# RSA certs
sudo certbot --apache -d mohamedesmael.work.gd \
  --cert-name mohamedesmael-rsa --non-interactive --agree-tos -m "$EMAIL"

sudo certbot --apache -d mohamedesmaelsonarqube.work.gd \
  --cert-name sonarqube-rsa --non-interactive --agree-tos -m "$EMAIL"

echo ""
echo "=== Restarting Apache cleanly ==="
if pgrep apache2 >/dev/null 2>&1; then
    echo "Apache already running, restarting…"
    sudo systemctl restart apache2
else
    echo "Starting Apache…"
    sudo systemctl start apache2
fi

echo ""
echo "✅ Apache and SSL setup complete"

echo ""
echo "=== Adding Dynamic DNS update jobs to crontab ==="

hosts=(
  "mohamedesmael.work.gd"
  "mohamedesmaelargocd.work.gd"
  "mohamedesmaelsonarqube.work.gd"
)

if [ -z "${DNS_EXIT_API_KEY:-}" ]; then
  echo "❌ Error: DNS_EXIT_API_KEY environment variable not set"
  exit 1
fi

api_key="$DNS_EXIT_API_KEY"
logfile="/var/log/ipupdate.log"

existing_crontab=$(crontab -l 2>/dev/null || true)
updated_crontab="$existing_crontab"

for host in "${hosts[@]}"; do
    command="curl -s https://api.dnsexit.com/dns/ud/?apikey=$api_key -d host=$host"
    if [ -d "/var/log" ]; then
        command="$command >> $logfile 2>&1"
    fi

    if grep -qF "$command" <<< "$existing_crontab"; then
        echo "Scheduled job for $host already exists in crontab."
    else
        updated_crontab="${updated_crontab}
*/12 * * * * $command"
        echo "Added scheduled job for $host."
    fi
done

echo "$updated_crontab" | crontab -

echo ""
echo "=== Crontab jobs configured. Current curl jobs: ==="
crontab -l | grep curl || echo "No curl jobs found"

echo ""
echo "🎉✅ All Done."
