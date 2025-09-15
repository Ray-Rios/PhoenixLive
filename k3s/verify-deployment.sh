#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}🔍 $1${NC}"
    echo "----------------------------------------"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_header "Phoenix Production Deployment Verification"

# Check namespace
print_header "Checking Namespace"
if kubectl get namespace phoenixapp &> /dev/null; then
    print_success "Namespace 'phoenixapp' exists"
else
    print_error "Namespace 'phoenixapp' not found"
fi

# Check deployments
print_header "Checking Deployments"
DEPLOYMENTS=("phoenix-web" "postgres" "redis")
for deployment in "${DEPLOYMENTS[@]}"; do
    if kubectl get deployment $deployment -n phoenixapp &> /dev/null; then
        READY=$(kubectl get deployment $deployment -n phoenixapp -o jsonpath='{.status.readyReplicas}')
        DESIRED=$(kubectl get deployment $deployment -n phoenixapp -o jsonpath='{.spec.replicas}')
        if [ "$READY" = "$DESIRED" ]; then
            print_success "$deployment: $READY/$DESIRED pods ready"
        else
            print_warning "$deployment: $READY/$DESIRED pods ready"
        fi
    else
        print_error "$deployment: deployment not found"
    fi
done

# Check services
print_header "Checking Services"
SERVICES=("phoenix-web" "db" "redis")
for service in "${SERVICES[@]}"; do
    if kubectl get service $service -n phoenixapp &> /dev/null; then
        print_success "Service '$service' exists"
    else
        print_error "Service '$service' not found"
    fi
done

# Check ingress
print_header "Checking Ingress"
if kubectl get ingress phoenix-ingress -n phoenixapp &> /dev/null; then
    print_success "Ingress 'phoenix-ingress' exists"
    
    # Check ingress IP
    INGRESS_IP=$(kubectl get ingress phoenix-ingress -n phoenixapp -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    if [ -n "$INGRESS_IP" ]; then
        print_success "Ingress has external IP: $INGRESS_IP"
    else
        print_warning "Ingress external IP is pending"
    fi
else
    print_error "Ingress 'phoenix-ingress' not found"
fi

# Check SSL certificates
print_header "Checking SSL Certificates"
if kubectl get certificate rio-tek-tls -n phoenixapp &> /dev/null; then
    CERT_READY=$(kubectl get certificate rio-tek-tls -n phoenixapp -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
    if [ "$CERT_READY" = "True" ]; then
        print_success "SSL certificate is ready"
    else
        print_warning "SSL certificate is not ready yet (this can take 5-10 minutes)"
        kubectl describe certificate rio-tek-tls -n phoenixapp | grep -A 5 "Events:"
    fi
else
    print_error "SSL certificate 'rio-tek-tls' not found"
fi

# Check secrets
print_header "Checking Secrets"
SECRETS=("phoenix-secrets" "rio-tek-tls")
for secret in "${SECRETS[@]}"; do
    if kubectl get secret $secret -n phoenixapp &> /dev/null; then
        print_success "Secret '$secret' exists"
    else
        print_warning "Secret '$secret' not found"
    fi
done

# Test health endpoint
print_header "Testing Health Endpoint"
if kubectl get pods -n phoenixapp -l app=phoenix-web --field-selector=status.phase=Running | grep -q phoenix-web; then
    print_success "Phoenix pods are running"
    
    # Port forward and test
    kubectl port-forward -n phoenixapp svc/phoenix-web 8080:80 &
    PF_PID=$!
    sleep 3
    
    if curl -s http://localhost:8080/health > /dev/null 2>&1; then
        print_success "Health endpoint is responding"
        HEALTH_RESPONSE=$(curl -s http://localhost:8080/health | jq -r '.status' 2>/dev/null || echo "unknown")
        echo "  Status: $HEALTH_RESPONSE"
    else
        print_warning "Health endpoint not responding"
    fi
    
    kill $PF_PID 2>/dev/null || true
else
    print_error "No running Phoenix pods found"
fi

# Check logs for errors
print_header "Checking Recent Logs"
echo "Recent Phoenix logs:"
kubectl logs --tail=10 deployment/phoenix-web -n phoenixapp 2>/dev/null || print_warning "Could not fetch logs"

# DNS check
print_header "DNS Configuration Check"
if command -v nslookup &> /dev/null; then
    DOMAIN_IP=$(nslookup rio-tek.com 2>/dev/null | grep -A 1 "Name:" | tail -1 | awk '{print $2}')
    if [ -n "$DOMAIN_IP" ]; then
        print_success "Domain rio-tek.com resolves to: $DOMAIN_IP"
        if [ "$DOMAIN_IP" = "$INGRESS_IP" ]; then
            print_success "Domain IP matches ingress IP"
        else
            print_warning "Domain IP ($DOMAIN_IP) does not match ingress IP ($INGRESS_IP)"
        fi
    else
        print_warning "Could not resolve rio-tek.com"
    fi
else
    print_warning "nslookup not available, skipping DNS check"
fi

# Final summary
print_header "Deployment Summary"
echo "🌐 Application URL: https://rio-tek.com"
echo "🔧 Admin Interface: https://mail.rio-tek.com (if Mailhog is enabled)"
echo "🏥 Health Check: https://rio-tek.com/health"
echo ""
echo "📋 Next Steps:"
echo "1. Configure SMTP credentials (see SMTP-SETUP-GUIDE.md)"
echo "2. Wait for SSL certificates to be issued (if pending)"
echo "3. Test your application functionality"
echo "4. Set up monitoring and backups"
echo ""
echo "🔧 Useful Commands:"
echo "  kubectl get all -n phoenixapp"
echo "  kubectl logs -f deployment/phoenix-web -n phoenixapp"
echo "  kubectl describe ingress phoenix-ingress -n phoenixapp"
echo "  kubectl get certificates -n phoenixapp"