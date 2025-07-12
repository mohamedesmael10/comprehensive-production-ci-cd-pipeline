#!/usr/bin/env bash
set -e

sudo apt-get update
sudo apt-get install -y apache2

# Enable Apache modules
sudo a2enmod proxy proxy_http proxy_html ssl

CONFIG_BASE=https://raw.githubusercontent.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/git-actions-pipeline/apache_configs

sudo curl -fsSL $CONFIG_BASE/jenkins.conf   -o /etc/apache2/sites-available/jenkins.conf
sudo curl -fsSL $CONFIG_BASE/sonarqube.conf -o /etc/apache2/sites-available/sonarqube.conf

sudo a2ensite jenkins.conf
sudo a2ensite sonarqube.conf

if command -v ufw >/dev/null 2>&1; then
  sudo ufw allow 80/tcp
  sudo ufw allow 443/tcp
fi

if pgrep apache2 >/dev/null 2>&1; then
    echo "Apache already running, restarting…"
    sudo apache2ctl restart
else
    echo "Starting Apache…"
    sudo apache2ctl start
fi

echo "Done"

echo ""
echo "=== Adding Dynamic DNS update jobs to crontab ==="

# List of hosts to update
hosts=(
  "mohamedesmael.work.gd"
  "mohamedesmaelargocd.work.gd"
  "mohamedesmaelsonarqube.work.gd"
)

if [ -z "$DNS_EXIT_API_KEY" ]; then
  echo "❌ Error: DNS_EXIT_API_KEY environment variable not set"
  exit 1
fi

api_key="$DNS_EXIT_API_KEY"
logfile="/var/log/ipupdate.log"

# Get the current crontab
existing_crontab=$(crontab -l 2>/dev/null || true)

updated_crontab="$existing_crontab"

for host in "${hosts[@]}"; do
    command="curl https://api.dnsexit.com/dns/ud/?apikey=$api_key -d host=$host"
    if [ -d "/var/log" ]; then
        command="$command >> $logfile"
    fi

    if grep -qF "$command" <<< "$existing_crontab"; then
        echo "Scheduled job for $host already exists in crontab."
    else
        updated_crontab="${updated_crontab}
*/12 * * * * $command"
        echo "Added scheduled job for $host."
    fi
done

# Install the updated crontab
echo "$updated_crontab" | crontab -

echo ""
echo "=== Crontab jobs configured. Current curl jobs: ==="
crontab -l | grep curl || echo "No curl jobs found"

echo ""
echo "✅ All Done."

