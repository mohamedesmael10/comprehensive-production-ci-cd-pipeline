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

if ! systemctl is-active --quiet apache2; then
  sudo systemctl enable --now apache2
fi

sudo systemctl restart apache2

echo "Done"
