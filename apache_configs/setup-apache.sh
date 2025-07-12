#!/usr/bin/env bash
set -euo pipefail

echo "=== Updating system and installing Apache & Certbot ==="
sudo apt-get update
sudo apt-get install -y apache2 certbot python3-certbot-apache curl

echo ""
echo "=== Enabling Apache modules ==="
sudo a2enmod proxy proxy_http proxy_html ssl rewrite headers

echo ""
echo "=== Starting Apache temporarily for HTTP (needed for certbot) ==="
sudo systemctl start apache2

CONFIG_BASE="https://raw.githubusercontent.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/git-actions-pipeline/apache_configs"

echo ""
echo "=== Downloading and enabling Apache HTTP site configs (pre-certbot) ==="
sudo curl -fsSL "$CONFIG_BASE/jenkins-http.conf"   -o /etc/apache2/sites-available/jenkins-http.conf
sudo curl -fsSL "$CONFIG_BASE/sonarqube-http.conf" -o /etc/apache2/sites-available/sonarqube-http.conf

sudo a2ensite jenkins-http.conf
sudo a2ensite sonarqube-http.conf

echo ""
echo "=== Reloading Apache with HTTP configs ==="
sudo systemctl reload apache2

if command -v ufw >/dev/null 2>&1; then
  echo ""
  echo "=== Configuring UFW firewall ==="
  sudo ufw allow 80/tcp
  sudo ufw allow 443/tcp
fi

echo ""
echo "=== Obtaining SSL certificates (RSA and ECDSA) ==="
EMAIL="mohamed.2714104@gmail.com"

declare -A hosts_certnames=(
  ["mohamedesmael.work.gd"]="mohamedesmael"
  ["mohamedesmaelsonarqube.work.gd"]="sonarqube"
)

for domain in "${!hosts_certnames[@]}"; do
    base="${hosts_certnames[$domain]}"
    echo ""
    echo "→ Requesting ECDSA cert for $domain"
    sudo certbot certonly --webroot -w /var/www/html -d "$domain" \
      --cert-name "${base}-ecdsa" --key-type ecdsa --elliptic-curve secp384r1 \
      --non-interactive --agree-tos -m "$EMAIL"

    echo ""
    echo "→ Requesting RSA cert for $domain"
    sudo certbot certonly --webroot -w /var/www/html -d "$domain" \
      --cert-name "${base}-rsa" --key-type rsa \
      --non-interactive --agree-tos -m "$EMAIL"
done

echo ""
echo "=== Switching Apache configs to SSL ==="

sudo a2dissite jenkins-http.conf
sudo a2dissite sonarqube-http.conf

sudo curl -fsSL "$CONFIG_BASE/jenkins-ssl.conf"   -o /etc/apache2/sites-available/jenkins-ssl.conf
sudo curl -fsSL "$CONFIG_BASE/sonarqube-ssl.conf" -o /etc/apache2/sites-available/sonarqube-ssl.conf

sudo a2ensite jenkins-ssl.conf
sudo a2ensite sonarqube-ssl.conf

echo ""
echo "=== Restarting Apache cleanly ==="
sudo systemctl restart apache2

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
