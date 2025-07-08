#!/bin/bash

set -e

# === 1. Create Node Exporter User ===
echo "Creating node_exporter user..."
sudo useradd --no-create-home --shell /bin/false node_exporter || true

# === 2. Download Node Exporter ===
echo "Downloading node_exporter..."
cd /tmp/
wget -q https://github.com/prometheus/node_exporter/releases/download/v1.3.1/node_exporter-1.3.1.linux-amd64.tar.gz

echo "Extracting..."
tar -xvf node_exporter-1.3.1.linux-amd64.tar.gz
cd node_exporter-1.3.1.linux-amd64

# === 3. Move Binary ===
sudo mv node_exporter /usr/local/bin/
sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter
sudo chcon -t bin_t /usr/local/bin/node_exporter || true  # Only applies to SELinux systems

# === 4. Create systemd service ===
echo "Creating systemd service for node_exporter..."
sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<EOF
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

# === 5. Start Service ===
echo "Starting node_exporter service..."
sudo systemctl daemon-reload
sudo systemctl enable --now node_exporter

# === 6. Add Prometheus Scrape Config ===
PROM_CONFIG="/etc/prometheus/prometheus.yml"
NODE_EXPORTER_JOB="
  - job_name: 'node_exporter'
    static_configs:
      - targets: ['localhost:9100']"

echo "Updating prometheus.yml..."

# Check if already added
if grep -q "job_name: 'node_exporter'" "$PROM_CONFIG"; then
  echo "Node Exporter scrape config already exists."
else
  awk -v job="$NODE_EXPORTER_JOB" '
    /scrape_configs:/ {
      print;
      print job;
      next
    }
    { print }
  ' "$PROM_CONFIG" > /tmp/prometheus.yml && sudo mv /tmp/prometheus.yml "$PROM_CONFIG"
  echo "Scrape config added to prometheus.yml"
fi

# === 7. Restart Prometheus ===
echo "Restarting Prometheus..."
if systemctl is-active --quiet prometheus; then
  sudo systemctl restart prometheus
  echo "Prometheus restarted."
else
  echo "Prometheus is not managed by systemd, restart it manually if needed."
fi

# === 8. Show Status ===
echo "Node Exporter Status:"
sudo systemctl status node_exporter --no-pager
