#!/bin/bash
set -e

# Usage help
if [[ "$*" == *"--help"* ]] || [[ "$*" == *"-h"* ]]; then
    cat << EOF
🚀 Phoenix LiveView Production Deployment Script

Usage: $0 [OPTIONS]

OPTIONS:
    --fresh         Fresh install mode: Delete database PVC and restore from backup
                    (Default: Preserve existing database between deployments)
    # NOTE: This script intentionally does NOT create a Kubernetes cluster.
    # It expects a kubeconfig/cluster to be available.
    --help, -h      Show this help message

EXAMPLES:
    $0              # Normal deployment - preserves database
    $0 --fresh      # Fresh install - wipes database and restores from backup

BEHAVIOR:
    Normal Mode (default):
        - Backs up database before deployment
        - Preserves postgres PVC across namespace deletion
        - Existing database data is kept intact
        - Only imports backup if database is empty
    
    Fresh Install Mode (--fresh):
        - Backs up database before deployment
        - Deletes database PVC (wipes all data)
        - Restores from most recent backup after deployment
        - Use this for clean slate deployments

EOF
    exit 0
fi

# CLI flags
# --fresh: fresh install
# The script uses a standard docker build; avoid build flags to preserve default behavior

# Check for --fresh flag
FRESH_INSTALL=false
if [[ "$*" == *"--fresh"* ]]; then
    FRESH_INSTALL=true
    echo "🆕 FRESH INSTALL MODE: Database will be completely wiped and restored from backup"
fi

# No custom build flags supported - docker image built with default cache semantics

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

# Database configuration
DB_USER=${DB_USER:-postgres}
DB_NAME=${DB_NAME:-phoenixapp_prod}
PGPASSWORD=${PGPASSWORD:-postgres}  # Set appropriately

# Backup directory
BACKUP_DIR=${BACKUP_DIR:-./backups}
mkdir -p "$BACKUP_DIR"
echo "📁 Using backup directory: $BACKUP_DIR"

if kubectl get namespace phoenixapp &> /dev/null; then
    echo "🍑 Backin'dat sql up (if exists)"
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    
    if ! kubectl get deployment -n phoenixapp postgres &>/dev/null; then
        print_warning "Postgres deployment not found, skipping database backup."
    else
        POD_NAME=$(kubectl get pods -n phoenixapp -l app=postgres -o jsonpath="{.items[0].metadata.name}")
        kubectl exec -n phoenixapp "$POD_NAME" -- env PGPASSWORD="$PGPASSWORD" pg_dump -U "$DB_USER" -h db -d "$DB_NAME" > "$BACKUP_DIR/db_backup_$TIMESTAMP.sql"
        # Keep only 10 most recent backups
        ls -t "$BACKUP_DIR"/db_backup_*.sql 2>/dev/null | tail -n +11 | xargs rm -f
        print_status "Database backed up"
    fi

    echo "🔴 Backing up Redis data..."
    if ! kubectl get deployment -n phoenixapp redis &>/dev/null; then
        print_warning "Redis deployment not found, skipping Redis backup."
    else
        REDIS_POD=$(kubectl get pods -n phoenixapp -l app=redis -o jsonpath="{.items[0].metadata.name}")
        if [ -n "$REDIS_POD" ]; then
            # Check if Redis is running
            if kubectl exec -n phoenixapp "$REDIS_POD" -- redis-cli ping 2>/dev/null | grep -q PONG; then
                # Create Redis backup using BGSAVE and copy the dump
                kubectl exec -n phoenixapp "$REDIS_POD" -- redis-cli BGSAVE
                # Wait for background save to complete
                echo "Waiting for Redis background save to complete..."
                sleep 10
                # Copy the dump file from the container to local backup directory
                if kubectl cp "phoenixapp/$REDIS_POD:/data/dump.rdb" "$BACKUP_DIR/redis_backup_$TIMESTAMP.rdb" 2>/dev/null; then
                    # Keep only 10 most recent Redis backups
                    ls -t "$BACKUP_DIR"/redis_backup_*.rdb 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true
                    print_status "Redis data backed up to redis_backup_$TIMESTAMP.rdb"
                else
                    print_warning "Failed to copy Redis dump file - Redis may be empty"
                fi
            else
                print_warning "Redis is not responding, skipping backup"
            fi
        else
            print_warning "No Redis pod found to backup"
        fi
    fi

    echo "🔐 Backing up Let's Encrypt certificates (multi-doc YAML)..."
    CERT_BACKUP_FILE="$BACKUP_DIR/letsencrypt_backup_${TIMESTAMP}.yaml"
    : > "$CERT_BACKUP_FILE"
    # Primary labeled secrets (each becomes its own document)
    for S in $(kubectl get secret -n phoenixapp -l cert-manager.io/certificate-name -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true); do
        kubectl get secret "$S" -n phoenixapp -o yaml 2>/dev/null >> "$CERT_BACKUP_FILE" || true
        echo "---" >> "$CERT_BACKUP_FILE"
    done
    # Additional TLS secrets with cert-manager annotations
    TLS_SECRET_NAMES=$(kubectl get secret -n phoenixapp -o jsonpath='{range .items[?(@.type=="kubernetes.io/tls")]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true)
    for S in $TLS_SECRET_NAMES; do
        HAS_CM=$(kubectl get secret "$S" -n phoenixapp -o jsonpath='{.metadata.annotations.cert-manager\.io/certificate-name}' 2>/dev/null || true)
        if [ -n "$HAS_CM" ]; then
            # Avoid duplicate (skip if already included above)
            if ! grep -q "name: $S" "$CERT_BACKUP_FILE"; then
                kubectl get secret "$S" -n phoenixapp -o yaml 2>/dev/null >> "$CERT_BACKUP_FILE" || true
                echo "---" >> "$CERT_BACKUP_FILE"
            fi
        fi
    done
    # Certificate CRs (each as its own document)
    for C in $(kubectl get certificates.cert-manager.io -n phoenixapp -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true); do
        kubectl get certificate "$C" -n phoenixapp -o yaml 2>/dev/null >> "$CERT_BACKUP_FILE" || true
        echo "---" >> "$CERT_BACKUP_FILE"
    done
    # Trim trailing separator if file ends with ---
    sed -i '$ {/^---$/d;}' "$CERT_BACKUP_FILE" 2>/dev/null || true
    # Symlink / copy latest for convenience
    if [ -s "$CERT_BACKUP_FILE" ]; then
        cp "$CERT_BACKUP_FILE" "$BACKUP_DIR/letsencrypt_backup.yaml"
        print_status "Certificates backed up to $CERT_BACKUP_FILE (latest copy: letsencrypt_backup.yaml)"
        # Keep only 10 most recent cert backups
        ls -t "$BACKUP_DIR"/letsencrypt_backup_*.yaml 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true
    else
        print_warning "No certificate data found to backup (possibly first issuance pending)"
        rm -f "$CERT_BACKUP_FILE" 2>/dev/null || true
    fi
fi

echo "🧹 Cleaning up old deployment..."

# Check if namespace exists and preserve PVCs if it does (unless --fresh flag is used)
if kubectl get namespace phoenixapp &> /dev/null; then
    if [ "$FRESH_INSTALL" = false ]; then
        echo "💾 Preserving PVCs before namespace deletion..."
        
        # Preserve postgres PVC (dynamic storage)
        if kubectl get pvc postgres-pvc -n phoenixapp &> /dev/null; then
            kubectl get pvc postgres-pvc -n phoenixapp -o yaml > "$BACKUP_DIR/postgres-pvc-backup.yaml"
            
            # Get the PV name
            PV_NAME=$(kubectl get pvc postgres-pvc -n phoenixapp -o jsonpath='{.spec.volumeName}')
            
            if [ -n "$PV_NAME" ]; then
                # Change the PV reclaim policy to Retain so it won't be deleted
                kubectl patch pv "$PV_NAME" -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'
                print_status "Database PV $PV_NAME set to Retain policy"
            fi
        fi
        
        # Preserve phoenix-uploads PV (manual storage - just needs reclaim policy)
        if kubectl get pv phoenix-uploads-local-pv &> /dev/null; then
            kubectl patch pv phoenix-uploads-local-pv -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'
            print_status "Phoenix uploads PV set to Retain policy"
        fi
    else
        echo "🗑️  Fresh install: PVCs will NOT be preserved"
        # Remove backup file if it exists
        rm -f "$BACKUP_DIR/postgres-pvc-backup.yaml"
    fi
fi

# Try to delete namespace, but continue even if it fails (e.g. EOF, doesn't exist, etc.)
kubectl delete namespace phoenixapp --ignore-not-found=true || echo "Namespace phoenixapp doesn't exist or couldn't be deleted - continuing anyway"

# Wait for namespace to be fully deleted
echo "⏳ Waiting for namespace to be fully deleted..."
while kubectl get namespace phoenixapp &> /dev/null; do
    echo -n "."
    sleep 2
done
echo ""
print_status "Namespace deleted"

# Reclaim retained PVs
echo "♻️  Reclaiming retained PVs..."

# Reclaim postgres PV (dynamic storage)
if [ -f "$BACKUP_DIR/postgres-pvc-backup.yaml" ]; then
    PV_NAME=$(grep "volumeName:" "$BACKUP_DIR/postgres-pvc-backup.yaml" | awk '{print $2}')
    
    if [ -n "$PV_NAME" ] && kubectl get pv "$PV_NAME" &> /dev/null; then
        PV_STATUS=$(kubectl get pv "$PV_NAME" -o jsonpath='{.status.phase}')
        
        if [ "$PV_STATUS" = "Released" ]; then
            # Remove claimRef to make it Available again
            kubectl patch pv "$PV_NAME" --type json -p='[{"op": "remove", "path": "/spec/claimRef"}]'
            print_status "Database PV $PV_NAME reclaimed"
        fi
    fi
fi

# Reclaim phoenix-uploads PV (manual storage)
if kubectl get pv phoenix-uploads-local-pv &> /dev/null; then
    PV_STATUS=$(kubectl get pv phoenix-uploads-local-pv -o jsonpath='{.status.phase}')
    
    if [ "$PV_STATUS" = "Released" ]; then
        # For manual storage class, we need to delete and recreate both PV and PVC
        echo "🔄 Recreating phoenix-uploads PV (manual storage class)..."
        kubectl delete pv phoenix-uploads-local-pv
        # PV will be recreated by kustomize
        print_status "Phoenix uploads PV will be recreated"
    fi
fi

# Reclaim phoenix-models PV (manual storage)
if kubectl get pv phoenix-models-local-pv &> /dev/null; then
    PV_STATUS=$(kubectl get pv phoenix-models-local-pv -o jsonpath='{.status.phase}')

    if [ "$PV_STATUS" = "Released" ]; then
        # Remove claimRef to make it Available again for phoenix-models-pvc
        kubectl patch pv phoenix-models-local-pv --type json -p='[{"op": "remove", "path": "/spec/claimRef"}]' 2>/dev/null || true
        print_status "Phoenix models PV reclaimed"
    fi
fi
echo "🐦‍🔥 Deploying Production"
echo "======================================"

# Pre-flight checks
echo "🔍 Running pre-flight checks..."

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi
print_status "kubectl is available"

# Check if Node.js is available
if ! command -v node &> /dev/null; then
    print_error "Node.js is not installed or not in PATH"
    exit 1
fi
print_status "Node.js is available"

# Note: Linting is handled by GitHub Actions CI
# Docker build will catch any real compilation errors
print_status "Skipping pre-deployment linting (handled by CI)"

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

echo "🔨 Building production Docker image with BuildKit..."

# Use multi-stage Dockerfile for faster builds
docker build --no-cache -f Dockerfile.multistage -t "phoenixapp:prod" --progress=plain --build-arg "MIX_ENV=prod" .
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

# Now deploy cluster issuers (path fix)
if [ -f "k3s/ssl/cluster-issuer.yaml" ]; then
    echo "🔐 Applying Let's Encrypt cluster issuers..."
    kubectl apply -f k3s/ssl/cluster-issuer.yaml
    print_status "Let's Encrypt cluster issuers applied"
else
    print_warning "Cluster issuer manifest k3s/ssl/cluster-issuer.yaml not found; skipping (ensure issuers exist)"
fi

# Restore certificates (Secrets + Cert CRs) BEFORE app deploy to avoid unnecessary re-issuance
LATEST_CERT_BACKUP=$(ls -t "$BACKUP_DIR"/letsencrypt_backup_*.yaml 2>/dev/null | head -1 || true)
if [ -n "$LATEST_CERT_BACKUP" ] && [ -s "$LATEST_CERT_BACKUP" ]; then
    # Improved heuristic: apply if file contains any Certificate kind OR any tls secret references
    if grep -q "kind: Certificate" "$LATEST_CERT_BACKUP" || grep -q "cert-manager.io/v1" "$LATEST_CERT_BACKUP"; then
        echo "🔓 Restoring certificate CRs (and any secrets) from $LATEST_CERT_BACKUP ..."
        if kubectl apply -f "$LATEST_CERT_BACKUP" 2>/dev/null; then
            print_status "Certificate CRs restored (cert-manager will reconcile secrets)"
        else
            print_warning "Validation/apply failed once; retrying with --validate=false"
            if kubectl apply --validate=false -f "$LATEST_CERT_BACKUP"; then
                print_status "Certificate CRs restored (validation disabled)"
            else
                print_warning "Failed to apply $LATEST_CERT_BACKUP; continuing"
            fi
        fi
    elif grep -q "tls.crt" "$LATEST_CERT_BACKUP" || grep -q "tls.key" "$LATEST_CERT_BACKUP"; then
        # Covers newly added 'Additional TLS Secrets' section
        echo "🔓 Restoring TLS secrets from $LATEST_CERT_BACKUP ..."
        if kubectl apply -f "$LATEST_CERT_BACKUP" 2>/dev/null; then
            print_status "TLS secrets restored"
        else
            print_warning "TLS secret apply failed; retrying with --validate=false"
            kubectl apply --validate=false -f "$LATEST_CERT_BACKUP" && print_status "TLS secrets restored (validation disabled)" || print_warning "Failed to apply TLS secrets; continuing"
        fi
    else
        print_warning "Certificate backup $LATEST_CERT_BACKUP has no Certificate CRs or TLS data; skipping restore"
    fi
else
    print_warning "No prior certificate backup found to restore"
fi

# Deploy the application (after restoring cert data)
echo "🚀 Deploying Phoenix application..."

# If we have a preserved database PVC, restore it BEFORE deploying
if [ -f "$BACKUP_DIR/postgres-pvc-backup.yaml" ]; then
    PV_NAME=$(grep "volumeName:" "$BACKUP_DIR/postgres-pvc-backup.yaml" | awk '{print $2}')
    
    if [ -n "$PV_NAME" ] && kubectl get pv "$PV_NAME" &> /dev/null; then
        echo "🔄 Restoring preserved database PVC..."
        
        # Create a clean PVC manifest that will bind to the existing PV
        STORAGE_CLASS=$(kubectl get pv "$PV_NAME" -o jsonpath='{.spec.storageClassName}')
        STORAGE_SIZE=$(kubectl get pv "$PV_NAME" -o jsonpath='{.spec.capacity.storage}')
        
        cat > "$BACKUP_DIR/postgres-pvc-clean.yaml" <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
  namespace: phoenixapp
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: ${STORAGE_SIZE}
  storageClassName: ${STORAGE_CLASS}
  volumeName: ${PV_NAME}
EOF
        
        # Apply the cleaned PVC - it will bind to the existing PV
        kubectl apply -f "$BACKUP_DIR/postgres-pvc-clean.yaml"
        
        # Wait for it to bind
        echo "⏳ Waiting for PVC to bind to preserved PV..."
        for i in {1..30}; do
            PVC_STATUS=$(kubectl get pvc postgres-pvc -n phoenixapp -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
            if [ "$PVC_STATUS" = "Bound" ]; then
                print_status "Database PVC restored and bound to existing data"
                break
            fi
            echo -n "."
            sleep 2
        done
        echo ""
        
        # Clean up temp file
        rm -f "$BACKUP_DIR/postgres-pvc-clean.yaml"
    fi
fi

# Deploy with server-side apply to handle existing PVC gracefully
kubectl apply --server-side=true --force-conflicts -k k3s/overlays/prod/
print_status "Application deployed"

# Check if phoenix-uploads-pvc is bound (manual storage class can be finicky)
echo "⏳ Checking phoenix-uploads-pvc binding..."
for i in {1..10}; do
    UPLOADS_PVC_STATUS=$(kubectl get pvc phoenix-uploads-pvc -n phoenixapp -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
    if [ "$UPLOADS_PVC_STATUS" = "Bound" ]; then
        print_status "Phoenix uploads PVC is bound"
        break
    elif [ "$UPLOADS_PVC_STATUS" = "Pending" ]; then
        if [ $i -eq 10 ]; then
            echo "⚠️  Phoenix uploads PVC stuck in Pending, attempting fix..."
            # Delete and recreate both PV and PVC for manual storage class
            kubectl delete pvc phoenix-uploads-pvc -n phoenixapp --force --grace-period=0 2>/dev/null || true
            sleep 2
            kubectl delete pv phoenix-uploads-local-pv --force --grace-period=0 2>/dev/null || true
            sleep 2
            kubectl apply -f k3s/base/phoenix-uploads-pv.yaml
            kubectl apply -f k3s/base/phoenix-uploads-pvc.yaml
            sleep 3
            print_status "Phoenix uploads PV/PVC recreated"
        fi
    fi
    echo -n "."
    sleep 2
done
echo ""

# Check if phoenix-models-pvc is bound (manual storage class can be finicky)
echo "⏳ Checking phoenix-models-pvc binding..."
for i in {1..10}; do
    MODELS_PVC_STATUS=$(kubectl get pvc phoenix-models-pvc -n phoenixapp -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
    if [ "$MODELS_PVC_STATUS" = "Bound" ]; then
        print_status "Phoenix models PVC is bound"
        break
    elif [ "$MODELS_PVC_STATUS" = "Pending" ]; then
        if [ $i -eq 10 ]; then
            echo "⚠️  Phoenix models PVC stuck in Pending, attempting fix..."
            # Delete and recreate both PV and PVC for manual storage class
            kubectl delete pvc phoenix-models-pvc -n phoenixapp --force --grace-period=0 2>/dev/null || true
            sleep 2
            kubectl delete pv phoenix-models-local-pv --force --grace-period=0 2>/dev/null || true
            sleep 2
            kubectl apply -f k3s/base/phoenix-models-pv.yaml
            kubectl apply -f k3s/base/phoenix-models-pvc.yaml
            sleep 3
            print_status "Phoenix models PV/PVC recreated"
        fi
    fi
    echo -n "."
    sleep 2
done
echo ""

# Wait for deployment to be ready
echo "⏳ Waiting for deployment to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/phoenix-web -n phoenixapp
kubectl wait --for=condition=available --timeout=300s deployment/postgres -n phoenixapp
print_status "Deployments are ready"

# Import database if backup exists AND database is empty (fresh install)
if [ -d "$BACKUP_DIR" ] && ls "$BACKUP_DIR"/db_backup_*.sql 1> /dev/null 2>&1; then
    if ! kubectl get deployment -n phoenixapp postgres &>/dev/null; then
        print_warning "Postgres deployment not found, skipping database import."
    else
        POD_NAME=$(kubectl get pods -n phoenixapp -l app=postgres -o jsonpath="{.items[0].metadata.name}")
        
        # Check if database has data (check if users table has rows)
        USER_COUNT=$(kubectl exec -n phoenixapp "$POD_NAME" -- env PGPASSWORD="$PGPASSWORD" psql -U "$DB_USER" -h db -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM users;" 2>/dev/null | tr -d ' ' || echo "0")
        
        if [ "$USER_COUNT" = "0" ]; then
            echo "📥 Database is empty, importing from backup..."
            LATEST_BACKUP=$(ls -t "$BACKUP_DIR"/db_backup_*.sql | head -1)
            
            # Scale down Phoenix pods to disconnect from database
            echo "📉 Scaling down Phoenix pods to release database connections..."
            kubectl scale deployment phoenix-web --replicas=0 -n phoenixapp
            kubectl wait --for=delete pod -l app=phoenix-web -n phoenixapp --timeout=120s
            
            # Wait a bit for connections to close
            sleep 5
            
            # Terminate remaining connections and drop database
            echo "🗑️ Dropping existing database for clean restore..."
            kubectl exec -n phoenixapp "$POD_NAME" -- env PGPASSWORD="$PGPASSWORD" psql -U "$DB_USER" -h db -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$DB_NAME' AND pid <> pg_backend_pid();"
            kubectl exec -n phoenixapp "$POD_NAME" -- env PGPASSWORD="$PGPASSWORD" psql -U "$DB_USER" -h db -d postgres -c "DROP DATABASE IF EXISTS $DB_NAME;"
            kubectl exec -n phoenixapp "$POD_NAME" -- env PGPASSWORD="$PGPASSWORD" psql -U "$DB_USER" -h db -d postgres -c "CREATE DATABASE $DB_NAME;"
            
            # Import the backup
            cat "$LATEST_BACKUP" | kubectl exec -i -n phoenixapp "$POD_NAME" -- env PGPASSWORD="$PGPASSWORD" psql -U "$DB_USER" -h db -d "$DB_NAME"
            print_status "Database imported from $LATEST_BACKUP"
            
            # Scale Phoenix pods back up
            echo "📈 Scaling Phoenix pods back up..."
            kubectl scale deployment phoenix-web --replicas=2 -n phoenixapp
            kubectl wait --for=condition=available --timeout=300s deployment/phoenix-web -n phoenixapp
        else
            print_status "Database already has data ($USER_COUNT users), skipping import to preserve existing data"
        fi
    fi
fi

# (Old post-deploy restore removed; restoration now occurs before application deployment)

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


cat << 'ASCIIART'
⢠⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠈⠙⠶⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⠓
⠀⠀⠀⠈⠙⠲⢤⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡼⠉⠀
⠀⠀⠛⠤⣠⡀⠀⠀⠉⠑⠳⠤⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⡴⠋⣁⡴⠃
⠀⠀⠀⠀⠀⠈⠉⠀⠀⠀⠀⢀⠈⠙⢄⡀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣠⠤⠤⡴⠂⠀⠀⠀⠀⢀⡤⡖⠉⠀⠖⠞⠁⢀⠀
⠀⠀⠀⠠⠤⣀⡀⠀⠀⠀⠀⢸⡀⠀⠀⠹⣆⠀⠀⠀⠀⠀⢀⣬⣠⠁⢀⠾⠉⠀⠀⠀⢀⣶⠋⠀⣧⢀⠀⣠⠤⠖⠉⠀
⠀⠀⠀⠀⠀⠉⠑⠒⠆⠀⠀⠸⡇⠀⠀⠀⠹⡦⠀⠀⠀⠀⠊⢩⠘⠀⢸⢀⠀⠀⠀⠀⣸⠉⠀⢠⡻⠈⠀⢋⣀⡤⠀⠀
⠀⠀⠀⠀⠀⠤⣀⣀⡀⠀⠀⠀⢳⠀⠀⠀⠀⠉⢧⣄⠀⢀⡀⡨⠀⠀⠀⢳⡄⠀⠀⣴⠃⠀⢀⣾⠁⠀⠘⠉⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠈⠙⠀⣀⠈⣧⣄⠀⠀⠀⠀⠑⠶⣀⣀⡀⠀⠀⠀⠀⢯⠶⠉⠀⢀⢀⡾⠈⠘⠚⠒⡤⠄⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⢤⠒⠊⠉⠁⠀⠈⠱⣄⡄⠀⠀⠀⠀⠀⠈⠁⠀⠀⠀⠀⢸⡆⣠⣠⠶⢫⣀⠋⠒⣴⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⠤⠚⠀⡀⠀⠉⠓⠒⠤⠤⠤⠴⠀⠀⠀⠀⠀⢸⡄⠈⠸⢤⠈⠉⢦⡠⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠾⠁⠀⠀⡴⠋⠀⢠⡆⠀⢀⠀⠀⡗⠀⠀⠀⠀⢠⢯⡙⢧⡄⠀⢷⡦⠀⠁⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠾⠃⢀⡴⠋⠀⡰⠏⠀⡞⠎⢰⢄⢀⣰⡟⠈⢲⡄⠹⠓⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⠁⠀⠘⠁⢀⠞⠀⠀⢸⡯⡟⠹⢶⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⠛⠀⣠⠞⠋⠀⡱⡱⠀⠘⠑⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡼⠉⠀⣼⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀Phoenix⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡞⡀⠀⢰⡁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀Live⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣸⡄⣿⠀⠌⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢻⠃⡏⠀⢹⠁⠀⢠⠶⠓⢧⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⡆⢹⠀⠀⢧⡀⡀⠀⢀⡼⠂⢀⠀⠀⠀⡴⠛⠉⠉⢦⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢹⣌⢧⣄⣰⠮⣩⠍⠉⠀⣠⠞⠂⠀⠀⢫⣤⣠⠀⣸⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠱⡎⠛⣷⣝⠶⢏⣩⣍⣁⣠⠀⠀⠀⠀⠀⠀⢠⡇⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢳⠀⠙⢻⣦⡈⠿⣍⣍⡉⠀⠀⠀⠀⣀⡠⠎⠁⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢧⠀⠀⠉⢫⣄⠈⠳⣈⠉⠉⠉⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⠀⠀⠀⠀⠩⡆⠀⠹⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⠂⠀⠀⠀⠀⣹⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
ASCIIART
