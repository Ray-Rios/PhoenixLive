
## Step 2: Update Email in SSL Configuration

Edit `k8s/ssl/cluster-issuer.yaml` and replace `admin@rio-tek.com` with your actual email address.

## Step 3: Deploy SSL Infrastructure

```powershell
cd k8s
.\setup-ssl.ps1
```

This will install:
- NGINX Ingress Controller
- cert-manager for automatic SSL certificates
- Let's Encrypt cluster issuers

## Step 4: Get External IP for DNS

```powershell
kubectl get svc -n ingress-nginx
```

Look for the `EXTERNAL-IP` of the `ingress-nginx-controller` service. Update your DNS records to point to this IP.

## Step 5: Deploy Production Application

```powershell
.\deploy-prod-ssl.ps1
```

This will:
- Build the production Docker image
- Deploy all services to the `phoenixapp` namespace
- Create ingress rules with SSL termination
- Request SSL certificates from Let's Encrypt

## Step 6: Verify Deployment

Check that everything is running:

```powershell
# Check pods
kubectl get pods -n phoenixapp

# Check certificates
kubectl get certificate -n phoenixapp

# Check ingress
kubectl get ingress -n phoenixapp
```

## Step 7: Access Your Application

Once certificates are issued (may take a few minutes):

- **Main App**: https://rio-tek.com
- **Main App (www)**: https://www.rio-tek.com  
- **Mailhog**: https://mail.rio-tek.com

## Troubleshooting

### Certificate Issues

Check certificate status:
```powershell
kubectl describe certificate rio-tek-tls -n phoenixapp
kubectl describe certificaterequest -n phoenixapp
```

### Ingress Issues

Check ingress controller logs:
```powershell
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
```

### Application Issues

Check Phoenix logs:
```powershell
kubectl logs -f deployment/phoenix-web -n phoenixapp
```

## SSL Certificate Renewal

Certificates are automatically renewed by cert-manager. No manual intervention required.

## Scaling Production

Scale the Phoenix application:
```powershell
kubectl scale deployment phoenix-web --replicas=3 -n phoenixapp
```



## Backup Considerations

- **Database**: PostgreSQL data is stored in persistent volumes
- **Redis**: Redis data is stored in persistent volumes
- **Certificates**: Managed automatically by cert-manager

## Security Notes

- All HTTP traffic is automatically redirected to HTTPS
- SSL certificates are automatically renewed
- Internal services communicate over cluster network
- Database passwords are stored in Kubernetes secrets