#!/usr/bin/env bash

# ------------------------------------------------------------
#  Bash version of "Deploy Phoenix App to Production with SSL"
#
#  It reproduces the same colour‑coded output you saw in PowerShell,
#  but works on any Unix‑like system (Linux, macOS, WSL …).
#
#  Dependencies:
#    - kubectl
#    - docker
#    - bash (obviously)
#
#  If you need a helper that sets up the Ingress‑NGINX controller and
#  cert-manager, rename it to `setup-ssl.sh` or change the call below.
# ------------------------------------------------------------
ENVIRONMENT="prod"
# ---- Colour helpers ---------------------------------------
GREEN="\e[32m"
YELLOW="\e[33m"
CYAN="\e[36m"
RESET="\e[0m"

log()   { echo -e "${GREEN}▶ ${1}${RESET}"; }
warn()  { echo -e "${YELLOW}⚠️ ${1}${RESET}"; }
info()  { echo -e "${CYAN}ℹ️  ${1}${RESET}"; }

# ---- Start -------------------------------------------------
log "Deploying Phoenix App to Production with SSL..."

# ---- Check if the Ingress‑NGINX controller is already running
if ! kubectl get pods -n ingress-nginx --no-headers >/dev/null 2>&1; then
    warn "SSL infrastructure not found. Setting up first…"
    # Make sure you have a script that does what setup‑ssl.ps1 did.
    if [[ -x ./setup-ssl.sh ]]; then
        ./setup-ssl.sh
    else
        warn "⚠️  No executable 'setup-ssl.sh' found – aborting."
        exit 1
    fi

    info "Waiting for SSL infrastructure to stabilize…"
    sleep 30   # adjust if you need more time
fi

# ---- Build the Docker image ---------------------------------
log "Building Phoenix Docker image for production…"
docker build -t "phoenixapp:$ENVIRONMENT" \
              --progress=plain \
              --build-arg "MIX_ENV=$ENVIRONMENT" \
              ../

# ---- Deploy Kubernetes manifests ----------------------------
log "Deploying to Kubernetes production environment…"
kubectl apply -f base/namespace.yaml
kubectl apply -k overlays/prod/

# ---- Wait for the pods to become ready ----------------------
info "Waiting for deployments to be ready…"

deployments=(
    postgres
    redis
    mailhog
    phoenix-web
)

for d in "${deployments[@]}"; do
    log "  Waiting for deployment/${d}…"
    kubectl wait --for=condition=available \
                 --timeout=300s deployment/"${d}" -n phoenixapp
done

# ---- Success message ----------------------------------------
log "Production environment deployed successfully!"
info "Your application will be available at:"
echo -e "${GREEN}https://rio-tek.com${RESET}"
echo -e "${GREEN}https://www.rio-tek.com${RESET}"
warn "Mailhog: https://mail.rio-tek.com"

# ---- Certificate status ------------------------------------
echo
warn "Checking SSL certificate status:"
kubectl get certificate -n phoenixapp

# ---- Ingress status -----------------------------------------
echo
warn "To check ingress status:"
info "kubectl get ingress -n phoenixapp"

# ---- External IP for DNS configuration ----------------------
echo
warn "To get the external IP for DNS configuration:"
info "kubectl get svc -n ingress-nginx"
