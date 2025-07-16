#!/bin/bash

set -e

echo "Checking cAdvisor container..."

if docker ps --format '{{.Names}}' | grep -q "^cadvisor$"; then
    echo "cAdvisor container is already running."
elif docker ps -a --format '{{.Names}}' | grep -q "^cadvisor$"; then
    echo "Removing stopped cAdvisor container..."
    docker rm cadvisor
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
    echo "cAdvisor started."
else
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
    echo "cAdvisor started."
fi

# === 2. Add scrape configs to Prometheus ===
PROM_CONFIG="/etc/prometheus/prometheus.yml"

CADVISOR_JOB="
  - job_name: 'cadvisor'
    static_configs:
      - targets: ['localhost:8081']"

# === Add cadvisor scrape config ===
if grep -q "job_name: 'cadvisor'" "$PROM_CONFIG"; then
  echo "cAdvisor scrape config already exists in prometheus.yml"
else
  echo "Adding cAdvisor scrape config to prometheus.yml"
  awk -v job="$CADVISOR_JOB" '
    /scrape_configs:/ {
      print;
      print job;
      next
    }
    { print }
  ' "$PROM_CONFIG" > /tmp/prometheus.yml && sudo mv /tmp/prometheus.yml "$PROM_CONFIG"
fi

# === 3. Restart Prometheus ===
echo "Restarting Prometheus..."
if systemctl is-active --quiet prometheus; then
  sudo systemctl restart prometheus
  echo "Prometheus restarted successfully"
else
  echo "Prometheus is not running via systemd, restart manually if needed"
fi
