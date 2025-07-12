#!/usr/bin/env bash
set -e

sudo apt-get update
sudo apt-get install -y apache2 libapache2-mod-proxy-html

#  Enable Apache modules
sudo a2enmod proxy proxy_http ssl


CONFIG_BASE=https://raw.githubusercontent.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/git-actions-pipeline/apache_configs

sudo curl -fsSL $CONFIG_BASE/jenkins.conf   -o /etc/apache2/sites-available/jenkins.conf
sudo curl -fsSL $CONFIG_BASE/sonarqube.conf -o /etc/apache2/sites-available/sonarqube.conf

sudo a2ensite jenkins.conf
sudo a2ensite sonarqube.conf

if command -v ufw >/dev/null 2>&1; then
  sudo ufw allow 80/tcp
  sudo ufw allow 443/tcp

fi

sudo systemctl reload apache2

echo "Done"
