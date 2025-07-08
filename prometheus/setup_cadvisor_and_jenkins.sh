#!/bin/bash

# === 1. Run cAdvisor Container ===
echo "Starting cAdvisor container..."
docker run \
  --volume=/:/rootfs:ro \
  --volume=/var/run:/var/run:ro \
  --volume=/sys:/sys:ro \
  --volume=/var/lib/docker/:/var/lib/docker:ro \
  --publish=8081:8080 \
  --detach=true \
  --name=cadvisor \
  gcr.io/cadvisor/cadvisor:latest

# === 2. Add scrape configs to Prometheus ===
PROM_CONFIG="/etc/prometheus/prometheus.yml"

CADVISOR_JOB="
  - job_name: 'cadvisor'
    static_configs:
      - targets: ['localhost:8081']"

JENKINS_JOB="
  - job_name: 'jenkins'
    metrics_path: '/prometheus'
    scheme: https
    static_configs:
      - targets: ['mohamedesmael.work.gd']"

# === Add cadvisor scrape config ===
if grep -q "job_name: 'cadvisor'" "$PROM_CONFIG"; then
  echo "✅ cAdvisor scrape config already exists in prometheus.yml"
else
  echo "➕ Adding cAdvisor scrape config to prometheus.yml"
  awk -v job="$CADVISOR_JOB" '
    /scrape_configs:/ {
      print;
      print job;
      next
    }
    { print }
  ' "$PROM_CONFIG" > /tmp/prometheus.yml && sudo mv /tmp/prometheus.yml "$PROM_CONFIG"
fi

# === Add jenkins scrape config ===
if grep -q "job_name: 'jenkins'" "$PROM_CONFIG"; then
  echo "✅ Jenkins scrape config already exists in prometheus.yml"
else
  echo "➕ Adding Jenkins scrape config to prometheus.yml"
  awk -v job="$JENKINS_JOB" '
    /scrape_configs:/ {
      print;
      print job;
      next
    }
    { print }
  ' "$PROM_CONFIG" > /tmp/prometheus.yml && sudo mv /tmp/prometheus.yml "$PROM_CONFIG"
fi

# === 3. Restart Prometheus ===
echo "🔁 Restarting Prometheus..."
if systemctl is-active --quiet prometheus; then
  sudo systemctl restart prometheus
  echo "✅ Prometheus restarted successfully"
else
  echo "⚠️ Prometheus is not running via systemd, restart manually if needed"
fi
