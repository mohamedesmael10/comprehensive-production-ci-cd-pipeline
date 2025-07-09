#!/bin/bash

set -e

# === 0. Hardcoded Credentials ===
GRAFANA_USER="admin"
GRAFANA_PASSWORD="admin"
GRAFANA_URL="http://localhost:3000"

# === Locate script dir ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

JENKINS_DASHBOARD_JSON="$SCRIPT_DIR/jenkins-dashboard.json"
PROMETHEUS_OVERVIEW_JSON="$SCRIPT_DIR/prometheus-overview.json"

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

# === 3. Add Prometheus Data Source ===
echo "🔌 Checking Prometheus data source in Grafana…"

if curl -s -u "$GRAFANA_USER:$GRAFANA_PASSWORD" "$GRAFANA_URL/api/datasources" | grep -q '"name":"Prometheus"'; then
  echo "✅ Prometheus data source already exists in Grafana"
else
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
fi

# === 4. Import Jenkins Dashboard ===
echo "📊 Importing Jenkins Dashboard from $JENKINS_DASHBOARD_JSON…"

IMPORT_STATUS_JENKINS=$(curl -s -o /tmp/import_jenkins_resp.json -w "%{http_code}" \
  -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
  -H "Content-Type: application/json" \
  -X POST "$GRAFANA_URL/api/dashboards/db" \
  --data-binary @"$JENKINS_DASHBOARD_JSON")

if [[ "$IMPORT_STATUS_JENKINS" == "200" || "$IMPORT_STATUS_JENKINS" == "201" ]]; then
  echo "✅ Jenkins Dashboard imported into Grafana"
else
  echo "❌ Failed to import Jenkins Dashboard. Response:"
  cat /tmp/import_jenkins_resp.json
  exit 1
fi

# === 5. Import Prometheus Overview Dashboard ===
echo "📊 Importing Prometheus Overview Dashboard from $PROMETHEUS_OVERVIEW_JSON…"

IMPORT_STATUS_PROM=$(curl -s -o /tmp/import_prom_resp.json -w "%{http_code}" \
  -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
  -H "Content-Type: application/json" \
  -X POST "$GRAFANA_URL/api/dashboards/db" \
  --data-binary @"$PROMETHEUS_OVERVIEW_JSON")

if [[ "$IMPORT_STATUS_PROM" == "200" || "$IMPORT_STATUS_PROM" == "201" ]]; then
  echo "✅ Prometheus Overview Dashboard imported into Grafana"
else
  echo "❌ Failed to import Prometheus Overview Dashboard. Response:"
  cat /tmp/import_prom_resp.json
  exit 1
fi

echo "🎉 Grafana setup complete!"
