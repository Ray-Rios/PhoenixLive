#!/bin/bash
set -e
echo "🧹 Cleaning up old deployment..."
kubectl delete namespace phoenixapp --ignore-not-found=true
echo "🚀 Deploying Production"
echo "======================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Pre-flight checks
echo "🔍 Running pre-flight checks..."

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi
print_status "kubectl is available"

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed or not in PATH"
    exit 1
fi
print_status "Docker is available"

# Check if we can connect to Kubernetes cluster
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi
print_status "Kubernetes cluster is accessible"

# Check if required namespaces exist or create them
echo "📦 Setting up namespaces..."
kubectl create namespace phoenixapp --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace ingress-nginx --dry-run=client -o yaml | kubectl apply -f -
print_status "Namespaces ready"

# Build production Docker image
echo "🔨 Building production Docker image..."
docker build -t "phoenixapp:prod" \
              --progress=plain \
              --build-arg "MIX_ENV=prod" \
              .
print_status "Production image built: phoenixapp:prod"

# Deploy SSL infrastructure first
echo "🔒 Deploying SSL infrastructure..."

# Install cert-manager with CRDs
echo "📦 Installing cert-manager..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml
print_status "Cert-manager with CRDs installed"

# Wait for cert-manager to be ready
echo "⏳ Waiting for cert-manager to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager -n cert-manager
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-webhook -n cert-manager
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-cainjector -n cert-manager
print_status "Cert-manager is ready"

# Install nginx ingress controller
echo "📦 Installing nginx ingress controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml
print_status "Nginx ingress controller installed"

# Wait for nginx ingress to be ready
echo "⏳ Waiting for nginx ingress to be ready..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s
print_status "Nginx ingress controller is ready"

# Now deploy cluster issuers
if [ -f "ssl/cluster-issuer.yaml" ]; then
    echo "🔐 Creating Let's Encrypt cluster issuers..."
    kubectl apply -f k3s/ssl/cluster-issuer.yaml
    print_status "Let's Encrypt cluster issuers deployed"
fi

# Deploy the application
echo "🚀 Deploying Phoenix application..."
kubectl apply -k k3s/overlays/prod/
print_status "Application deployed"

# Wait for deployment to be ready
echo "⏳ Waiting for deployment to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/phoenix-web -n phoenixapp
kubectl wait --for=condition=available --timeout=300s deployment/postgres -n phoenixapp
print_status "Deployments are ready"

# Check pod status
echo "📊 Checking pod status..."
kubectl get pods -n phoenixapp

# Check ingress status
echo "🌐 Checking ingress status..."
kubectl get ingress -n phoenixapp

# Get external IP
echo "🔗 Getting external access information..."
EXTERNAL_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
if [ "$EXTERNAL_IP" != "pending" ] && [ "$EXTERNAL_IP" != "" ]; then
    print_status "External IP: $EXTERNAL_IP"
else
    print_warning "External IP is still pending. Check your LoadBalancer service."
fi

# Test health endpoint (if accessible)
echo "🏥 Testing health endpoint..."
if kubectl get pods -n phoenixapp -l app=phoenix-web --field-selector=status.phase=Running | grep -q phoenix-web; then
    # Port forward to test health endpoint
    kubectl port-forward -n phoenixapp svc/phoenix-web 8080:80 &
    PF_PID=$!
    sleep 3
    
    if curl -s http://localhost:8080/health > /dev/null; then
        print_status "Health endpoint is responding"
    else
        print_warning "Health endpoint not responding yet"
    fi
    
    kill $PF_PID 2>/dev/null || true
fi

echo ""
echo "🎉 Deployment completed!"
echo ""
echo "======================================"
echo "Useful commands:"
echo "  kubectl get pods -n phoenixapp"
echo "  kubectl logs -f deployment/phoenix-web -n phoenixapp"
echo "  kubectl get certificates -n phoenixapp"
echo "  kubectl describe ingress phoenix-ingress -n phoenixapp"