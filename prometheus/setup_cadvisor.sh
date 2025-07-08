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

# === 2. Add cAdvisor scrape config to Prometheus ===

PROM_CONFIG="/etc/prometheus/prometheus.yml"
CADVISOR_JOB="
  - job_name: 'cadvisor'
    static_configs:
      - targets: ['localhost:8081']"

# Check if job already exists to avoid duplicates
if grep -q "job_name: 'cadvisor'" "$PROM_CONFIG"; then
  echo "cAdvisor scrape config already exists in prometheus.yml"
else
  echo "Adding cAdvisor scrape config to prometheus.yml"
  # Insert under scrape_configs
  awk -v job="$CADVISOR_JOB" '
    /scrape_configs:/ {
      print;
      print job;
      next
    }
    { print }
  ' "$PROM_CONFIG" > /tmp/prometheus.yml && sudo mv /tmp/prometheus.yml "$PROM_CONFIG"

  echo "Successfully updated prometheus.yml"
fi

# === 3. Restart Prometheus ===
echo "Restarting Prometheus..."
if systemctl is-active --quiet prometheus; then
  sudo systemctl restart prometheus
  echo "Prometheus restarted"
else
  echo "Prometheus is not running via systemd, restart manually if needed"
fi
