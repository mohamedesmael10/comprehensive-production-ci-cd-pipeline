#!/bin/bash

set -e

# === 0. Hardcoded Credentials ===
GRAFANA_USER="admin"
GRAFANA_PASSWORD="admin"
JENKINS_HOST="mohamedesmael.work.gd"
GRAFANA_URL="http://localhost:3000"

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

# === 2. Wait for Grafana API ===
echo "⏳ Waiting for Grafana API to become ready…"
timeout=60
while ! curl -sf "$GRAFANA_URL/login" > /dev/null; do
    sleep 2
    timeout=$((timeout-2))
    if [ $timeout -le 0 ]; then
        echo "❌ Grafana API did not become ready within 60 seconds"
        exit 1
    fi
done
echo "✅ Grafana API is ready"

# === 3. Connect Grafana to Prometheus ===
echo "🔌 Adding Prometheus as a Grafana data source…"

ADD_DS_STATUS=$(curl -s -o /tmp/add_ds_resp.json -w "%{http_code}" -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
  -H "Content-Type: application/json" \
  -X POST "$GRAFANA_URL/api/datasources" \
  -d '{
    "name": "Prometheus",
    "type": "prometheus",
    "url": "http://localhost:9090",
    "access": "proxy",
    "basicAuth": false
  }')

if [[ "$ADD_DS_STATUS" == "200" || "$ADD_DS_STATUS" == "201" ]]; then
  echo "✅ Prometheus added as a Grafana data source"
else
  echo "❌ Failed to add Prometheus data source. Response:"
  cat /tmp/add_ds_resp.json
  exit 1
fi

# === 4. Import Jenkins Dashboard ===
echo "📊 Importing Jenkins Dashboard…"

IMPORT_STATUS=$(curl -s -o /tmp/import_dash_resp.json -w "%{http_code}" -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
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
  }')

if [[ "$IMPORT_STATUS" == "200" || "$IMPORT_STATUS" == "201" ]]; then
  echo "✅ Jenkins Dashboard imported into Grafana"
else
  echo "❌ Failed to import Jenkins Dashboard. Response:"
  cat /tmp/import_dash_resp.json
  exit 1
fi
