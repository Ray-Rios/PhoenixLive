#!/usr/bin/env bash

# ------------------------------------------------------------
#  Bash version of "Setup SSL infrastructure for rio‑tek.com"
#
#  Dependencies:
#    - kubectl
#    - bash
#
#  It reproduces the colour‑coded output you had in PowerShell.
# ------------------------------------------------------------

# ---- Colour helpers ---------------------------------------
GREEN="\e[32m"
YELLOW="\e[33m"
CYAN="\e[36m"
RESET="\e[0m"

log()   { echo -e "${GREEN}▶ ${1}${RESET}"; }
warn()  { echo -e "${YELLOW}⚠️ ${1}${RESET}"; }
info()  { echo -e "${CYAN}ℹ️  ${1}${RESET}"; }

# ---- Start -------------------------------------------------
log "Setting up SSL infrastructure for rio-tek.com…"

# ---- Create namespaces ------------------------------------
warn "Creating namespaces…"
kubectl apply -f ssl/nginx-ingress.yaml
kubectl apply -f ssl/cert-manager.yaml

# ---- Install NGINX Ingress Controller ----------------------
warn "Installing NGINX Ingress Controller…"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml

info "Waiting for NGINX Ingress Controller to be ready…"
kubectl wait --namespace ingress-nginx \
             --for=condition=ready pod \
             --selector=app.kubernetes.io/component=controller \
             --timeout=300s

# ---- Install cert‑manager ----------------------------------
warn "Installing cert-manager…"
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml

info "Waiting for cert-manager to be ready…"
sleep 30   # give the pods a moment to start
kubectl wait --namespace cert-manager \
             --for=condition=ready pod \
             --selector=app.kubernetes.io/name=cert-manager \
             --timeout=300s

# ---- Create Let's Encrypt ClusterIssuer --------------------
warn "Creating Let's Encrypt cluster issuers…"
kubectl apply -f ssl/cluster-issuer.yaml

# ---- Finished ---------------------------------------------
log "SSL infrastructure setup complete!"
info "You can now deploy production with SSL support."

echo
warn "To get the external IP for your domain DNS:"
info "kubectl get svc -n ingress-nginx"

