#!/bin/bash

if ! command -v kubectl &> /dev/null
then
    echo "===> kubectl not found. Installing kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
fi

# Install K3d
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# Create K3d cluster mapping port 8888 for the application
k3d cluster create Clusterr -p "8080:80@loadbalancer" -p "8888:8888@loadbalancer"

# Create required namespaces
kubectl create namespace argocd
kubectl create namespace dev

# Install Argo CD
kubectl apply -n argocd --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for Argo CD to initialize
echo "Waiting for Argo CD pods to be ready..."
sleep 5
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

# Apply the Argo CD application tracking the GitHub repo
kubectl apply -f ../confs/app.yaml

# Retrieve admin password
# Wait for the secret to actually be created by Argo CD
echo "===> Waiting for admin password to be generated..."
while ! kubectl -n argocd get secret argocd-initial-admin-secret &>/dev/null; do
    sleep 2
done

# Now it is safe to retrieve the password
PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

# Expose Argo CD UI
kubectl port-forward svc/argocd-server -n argocd 8081:443 > /dev/null 2>&1 &
kubectl port-forward svc/argocd-server -n argocd 8082:80 > /dev/null 2>&1 &
sleep 2

#clear
echo "===> Setup Complete"
echo "Argo CD URL: https://localhost:8081"
echo "Argo CD URL: http://localhost:8082"
echo "Username: admin"
echo "Password: $PASSWORD"
