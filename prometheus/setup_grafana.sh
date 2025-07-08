#!/bin/bash

set -e

# === 0. Hardcoded Credentials ===
GRAFANA_USER="admin"
GRAFANA_PASSWORD="admin"

JENKINS_HOST="mohamedesmael.work.gd"

# === 1. Install Grafana ===
echo "📦 Installing Grafana..."

# Add Grafana APT repo
sudo apt-get install -y software-properties-common
sudo add-apt-repository "deb https://packages.grafana.com/oss/deb stable main" -y
wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -

# Install Grafana
sudo apt-get update
sudo apt-get install -y grafana

# Start Grafana service
sudo systemctl daemon-reexec
sudo systemctl enable --now grafana-server
echo "✅ Grafana installed and running at http://localhost:3000"

# === 2. Connect Grafana to Prometheus ===
echo "🔌 Connecting Grafana to Prometheus..."

GRAFANA_URL="http://localhost:3000"

EXISTING=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASSWORD" "$GRAFANA_URL/api/datasources" | grep -c '"name":"Prometheus"')

if [ "$EXISTING" -eq 0 ]; then
  echo "➕ Adding Prometheus data source to Grafana..."

  curl -s -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
    -H "Content-Type: application/json" \
    -X POST "$GRAFANA_URL/api/datasources" \
    -d '{
      "name": "Prometheus",
      "type": "prometheus",
      "url": "http://localhost:9090",
      "access": "proxy",
      "basicAuth": false
    }'

  echo "✅ Prometheus added as a Grafana data source"
else
  echo "✅ Prometheus data source already exists in Grafana"
fi

# === 3. Import Jenkins Dashboard ===
echo "📊 Importing Jenkins Dashboard..."

curl -s -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
  -H "Content-Type: application/json" \
  -X POST "$GRAFANA_URL/api/dashboards/import" \
  -d '{
    "dashboard": {
      "id": 9964
    },
    "overwrite": true,
    "inputs": [
      {
        "name": "DS_PROMETHEUS",
        "type": "datasource",
        "pluginId": "prometheus",
        "value": "Prometheus"
      }
    ]
  }' > /dev/null

echo "✅ Jenkins Dashboard imported into Grafana"
