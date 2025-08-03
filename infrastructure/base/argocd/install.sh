#!/bin/bash
# ArgoCD Installation Script for K3s Homelab
# File: infrastructure/base/argocd/install.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# Configuration - Update these for your environment
ARGOCD_NAMESPACE=${ARGOCD_NAMESPACE:-"argocd"}
VALUES_FILE=${VALUES_FILE:-"values.yml"}

# Validate cluster connectivity
log "Validating K3s cluster connectivity..."
if ! kubectl cluster-info >/dev/null 2>&1; then
    error "Cannot connect to K3s cluster. Please check kubectl configuration."
fi

# Create ArgoCD namespace
log "Creating ArgoCD namespace..."
kubectl create namespace ${ARGOCD_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# Add ArgoCD Helm repository
log "Adding ArgoCD Helm repository..."
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Validate values file exists
if [[ ! -f "${VALUES_FILE}" ]]; then
    error "Values file '${VALUES_FILE}' not found. Please ensure values.yaml is in the current directory."
fi

# Install ArgoCD
log "Installing ArgoCD with custom values..."
helm upgrade --install argocd argo/argo-cd \
  --namespace ${ARGOCD_NAMESPACE} \
  --values ${VALUES_FILE} \
  --wait \
  --timeout 10m

# Wait for ArgoCD server to be ready
log "Waiting for ArgoCD server to be ready..."
kubectl wait --for=condition=available \
  --timeout=600s \
  deployment/argocd-server \
  -n ${ARGOCD_NAMESPACE}

# Get initial admin password
log "Retrieving ArgoCD admin password..."
ARGOCD_PASSWORD=$(kubectl -n ${ARGOCD_NAMESPACE} get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)

# Display connection information
log "ArgoCD installation completed successfully!"
echo ""
echo "======================="
echo "ArgoCD Access Information"
echo "======================="
echo "URL: Check your ingress configuration or LoadBalancer IP"
echo "Username: admin"
echo "Password: $ARGOCD_PASSWORD"
echo ""
echo "To connect via ArgoCD CLI:"
echo "argocd login <your-argocd-url> --username admin --password '$ARGOCD_PASSWORD' --insecure"
echo ""
echo "IMPORTANT: Save this password securely and consider changing it after first login"
echo ""

# Verify installation
log "Verifying ArgoCD installation..."
kubectl get pods -n ${ARGOCD_NAMESPACE}
kubectl get svc -n ${ARGOCD_NAMESPACE}
kubectl get ingress -n ${ARGOCD_NAMESPACE} 2>/dev/null || log "No ingress configured"

log "Installation verification completed!"
log "Next steps:"
log "1. Configure DNS records for your ArgoCD domain"
log "2. Access the ArgoCD UI and change the admin password"
log "3. Configure your Git repositories"
log "4. Deploy your applications using the app-of-apps pattern"
