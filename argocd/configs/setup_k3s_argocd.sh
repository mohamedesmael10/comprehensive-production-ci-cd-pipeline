#!/bin/bash

set -e

### CONFIGURATION ###
K8S_USER=$(whoami)
K8S_GROUP=$(id -gn)
ARGOCD_DOMAIN="mohamedesmaelargocd.work.gd"
EMAIL="mohamed.2714104@gmail.com"

### 1️⃣ Install Docker ###
echo "🚀 Installing Docker..."
sudo apt-get update
sudo apt-get install -y docker.io
sudo systemctl enable docker
sudo systemctl start docker

### 2️⃣ Install kubeadm, kubelet, kubectl ###
echo "🚀 Installing kubeadm, kubelet, kubectl..."
sudo apt-get update && sudo apt-get install -y apt-transport-https curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

### 3️⃣ Disable swap (required for kubeadm) ###
echo "🚀 Disabling swap..."
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

### 4️⃣ Initialize Kubernetes cluster ###
echo "🚀 Initializing Kubernetes cluster..."
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

### 5️⃣ Setup kubeconfig for current user ###
echo "🚀 Setting up kubeconfig..."
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown "${K8S_USER}:${K8S_GROUP}" $HOME/.kube/config
chmod 400 $HOME/.kube/config
export KUBECONFIG=$HOME/.kube/config

### 6️⃣ Install Flannel network plugin ###
echo "🚀 Installing Flannel CNI plugin..."
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

### 7️⃣ Install ArgoCD ###
echo "🚀 Installing ArgoCD..."
kubectl create namespace argocd || true
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "🔄 Patching ArgoCD service to NodePort..."
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort"}}'

### 8️⃣ Fetch Initial Admin Password ###
echo "🔑 Fetching ArgoCD initial admin password..."
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "ArgoCD initial admin password: ${ARGOCD_PASSWORD}"

### 9️⃣ Enable TLS with Ingress ###

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

### 🔟 Install ArgoCD CLI ###
echo "🚀 Installing ArgoCD CLI..."
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64

echo "🎉 All done!"
