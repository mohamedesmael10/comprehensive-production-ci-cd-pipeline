#!/bin/bash

set -eo pipefail

GRAFANA_USER="admin"
GRAFANA_PASSWORD="admin"
GRAFANA_URL="http://localhost:3000"

PROMETHEUS_OVERVIEW_JSON="../prometheus/prometheus-overview.json"

if systemctl is-active --quiet grafana-server; then
    echo "✅ Grafana is already installed and running."
else
    echo "📦 Installing Grafana..."

    sudo apt-get install -y apt-transport-https software-properties-common wget gpg
    sudo mkdir -p /etc/apt/keyrings/
    wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null

    echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list

    sudo apt-get update
    sudo apt-get install -y grafana

    sudo systemctl daemon-reexec
    sudo systemctl enable --now grafana-server
    echo "✅ Grafana installed and running at http://localhost:3000"
fi

echo "⏳ Waiting for Grafana API to become ready…"
timeout=60
while ! curl -sf "$GRAFANA_URL/login" > /dev/null; do
    sleep 2
    timeout=$((timeout-2))
    if [ $timeout -le 0 ]; then
        echo "❌ Grafana API did not become ready within 60 seconds"
        exit 0
    fi
done
echo "✅ Grafana API is ready"

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
        exit 0
    fi
fi

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
    exit 0
fi

echo "🎉 Grafana setup complete!"
