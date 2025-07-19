#!/bin/bash

set -eo pipefail

### CONFIGURATION ###
K8S_USER=$(whoami)
K8S_GROUP=$(id -gn)
ARGOCD_DOMAIN="mohamedesmaelargocd.work.gd"
EMAIL="mohamed.2714104@gmail.com"
GIT_REPO="https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline.git"
GIT_BRANCH="git-actions-pipeline"
GIT_PATH="argocd"
APP_NAME="my-app"

echo "💡 Starting setup for local GitOps with ArgoCD on Minikube..."

### 1️⃣ Install Docker ###
echo "📦 Installing Docker..."
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo tee /etc/apt/keyrings/docker.asc > /dev/null
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
### 2️⃣ Install kubectl ###
echo "📦 Installing kubectl..."
KUBECTL_VERSION=$(curl -sL https://dl.k8s.io/release/stable.txt)
curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

### 3️⃣ Install Minikube ###
echo "📦 Installing Minikube..."
curl -LO https://github.com/kubernetes/minikube/releases/latest/download/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
rm minikube-linux-amd64

### 4️⃣ Start Minikube ###
echo "🚀 Starting Minikube..."
sudo minikube start --driver=docker --force

### 5️⃣ Install ArgoCD ###
echo "🚀 Installing ArgoCD..."
kubectl create namespace argocd || true
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "⏳ Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=Available=True deploy/argocd-server -n argocd --timeout=180s

kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort"}}'

### 6️⃣ Get ArgoCD Admin Password ###
echo "🔑 ArgoCD admin password:"
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "${ARGOCD_PASSWORD}"

### 7️⃣ Install Helm & Cert-Manager ###
echo "📦 Installing Cert-Manager..."
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --version v1.11.0 --set installCRDs=true

### 8️⃣ ClusterIssuer ###
echo "🔐 Creating ClusterIssuer..."
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

### 9️⃣ Install NGINX Ingress ###
echo "🌐 Installing Ingress NGINX..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.7.0/deploy/static/provider/cloud/deploy.yaml
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=180s

### 🔟 Create Ingress for ArgoCD ###
echo "🌐 Creating Ingress for ArgoCD..."
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-ingress
  namespace: argocd
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    kubernetes.io/ingress.class: nginx
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

### 🧪 Install ArgoCD CLI ###
echo "🧰 Installing ArgoCD CLI..."
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64

### 🔑 Login to ArgoCD CLI ###
echo "🔐 Logging into ArgoCD CLI..."
ARGOCD_IP=$(minikube service argocd-server -n argocd --url | tr ' ' '\n' | head -n1 | sed 's|http://||')

argocd login ${ARGOCD_IP} --username admin --password ${ARGOCD_PASSWORD} --insecure

### 🚀 Create and Sync App ###
echo "🚀 Creating ArgoCD Application: $APP_NAME"
argocd app create ${APP_NAME} \
  --repo ${GIT_REPO} \
  --revision ${GIT_BRANCH} \
  --path ${GIT_PATH} \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default \
  --server ${ARGOCD_IP} --insecure

argocd app set ${APP_NAME} --sync-policy automated --server ${ARGOCD_IP} --insecure
argocd app sync ${APP_NAME} --server ${ARGOCD_IP} --insecure
argocd app wait ${APP_NAME} --server ${ARGOCD_IP} --insecure

echo "🎉 Deployment complete! Visit: https://${ARGOCD_DOMAIN} to access ArgoCD UI."

sleep 10s

