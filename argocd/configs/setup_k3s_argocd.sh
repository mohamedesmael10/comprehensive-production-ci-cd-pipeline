#!/bin/bash

set -e

### CONFIGURATION ###
K8S_USER=$(whoami)
K8S_GROUP=$(id -gn)
ARGOCD_DOMAIN="mohamedesmaelargocd.work.gd"
EMAIL="mohamed.2714104@gmail.com"

### 1️⃣ Install K3s ###
echo "🚀 Installing K3s..."
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server" sh -s - --disable traefik

echo "✅ K3s installed. Exporting kubeconfig..."
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown "${K8S_USER}:${K8S_GROUP}" ~/.kube/config
chmod 400 ~/.kube/config
export KUBECONFIG=~/.kube/config

### 2️⃣ Install ArgoCD ###
echo "🚀 Installing ArgoCD..."
kubectl create namespace argocd || true
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "🔄 Patching ArgoCD service to NodePort..."
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort"}}'

### 3️⃣ Fetch Initial Admin Password ###
echo "🔑 Fetching ArgoCD initial admin password..."
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "ArgoCD initial admin password: ${ARGOCD_PASSWORD}"

### 4️⃣ Enable TLS with Ingress ###
echo "✨ Enabling TLS with Ingress..."

echo "🚀 Installing Cert-Manager via Helm..."
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --version v1.11.0 --set installCRDs=true

echo "🔄 Creating ClusterIssuer for LetsEncrypt..."
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: ${EMAIL}
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - http01:
          ingress:
            class: nginx
EOF

echo "🚀 Installing NGINX Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.7.0/deploy/static/provider/cloud/deploy.yaml

echo "🔄 Creating Ingress for ArgoCD..."
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-ingress
  namespace: argocd
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    kubernetes.io/ingress.class: nginx
    kubernetes.io/tls-acme: "true"
    nginx.ingress.kubernetes.io/ssl-passthrough: "true"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
spec:
  rules:
  - host: ${ARGOCD_DOMAIN}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              name: https
  tls:
  - hosts:
    - ${ARGOCD_DOMAIN}
    secretName: argocd-secret
EOF

echo "✅ Ingress & TLS configuration applied."

### 5️⃣ Install ArgoCD CLI ###
echo "🚀 Installing ArgoCD CLI..."
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64

### 6️⃣ Login & Update Password ###
echo "🔐 Login to ArgoCD CLI..."
argocd login ${ARGOCD_DOMAIN} --username admin --password "${ARGOCD_PASSWORD}" --insecure

echo "🔄 You can now update the password using: argocd account update-password"

echo "🎉 All done!"
