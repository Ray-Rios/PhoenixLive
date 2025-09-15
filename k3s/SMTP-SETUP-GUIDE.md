# SMTP Configuration Guide 📧

## Quick Setup for Popular Providers

### 1. SendGrid (Recommended)
```yaml
# In k3s/overlays/prod/configmap.yaml
SMTP_HOST: "smtp.sendgrid.net"
SMTP_PORT: "587"

# In k3s/overlays/prod/secrets.yaml
SMTP_USER: "apikey"  # Always "apikey" for SendGrid
SMTP_PASS: "SG.your-sendgrid-api-key-here"
```

**Setup Steps:**
1. Sign up at https://sendgrid.com
2. Go to Settings > API Keys
3. Create a new API key with "Mail Send" permissions
4. Use "apikey" as username and the API key as password

### 2. Mailgun
```yaml
# In k3s/overlays/prod/configmap.yaml
SMTP_HOST: "smtp.mailgun.org"
SMTP_PORT: "587"

# In k3s/overlays/prod/secrets.yaml
SMTP_USER: "postmaster@your-domain.mailgun.org"
SMTP_PASS: "your-mailgun-smtp-password"
```

### 3. Amazon SES
```yaml
# In k3s/overlays/prod/configmap.yaml
SMTP_HOST: "email-smtp.us-east-1.amazonaws.com"  # Change region as needed
SMTP_PORT: "587"

# In k3s/overlays/prod/secrets.yaml
SMTP_USER: "your-ses-smtp-username"
SMTP_PASS: "your-ses-smtp-password"
```

### 4. Gmail (Not recommended for production)
```yaml
# In k3s/overlays/prod/configmap.yaml
SMTP_HOST: "smtp.gmail.com"
SMTP_PORT: "587"

# In k3s/overlays/prod/secrets.yaml
SMTP_USER: "your-email@gmail.com"
SMTP_PASS: "your-app-password"  # Not your regular password!
```

## Configuration Steps

### 1. Update ConfigMap
Edit `k3s/overlays/prod/configmap.yaml`:
```bash
kubectl edit configmap phoenix-config -n phoenixapp
```

### 2. Update Secrets
Edit `k3s/overlays/prod/secrets.yaml` and apply:
```bash
# Edit the file with your credentials
kubectl apply -f k3s/overlays/prod/secrets.yaml
```

### 3. Restart Phoenix Pods
```bash
kubectl rollout restart deployment/phoenix-web -n phoenixapp
```

### 4. Test Email Functionality
```bash
# Port forward to test
kubectl port-forward -n phoenixapp svc/phoenix-web 8080:80

# Test in your application or use Phoenix console
kubectl exec -it deployment/phoenix-web -n phoenixapp -- mix phx.server
```

## Security Best Practices

### ✅ Do This
- Use API keys instead of passwords when possible
- Store credentials in Kubernetes secrets (not ConfigMaps)
- Use TLS/STARTTLS (port 587 or 465)
- Rotate credentials regularly
- Use dedicated SMTP service accounts

### ❌ Don't Do This
- Store credentials in plain text files
- Use personal email accounts for production
- Use unencrypted SMTP (port 25)
- Hardcode credentials in application code

## Troubleshooting

### Common Issues

**1. Authentication Failed**
```bash
# Check if credentials are correct
kubectl get secret phoenix-secrets -n phoenixapp -o yaml
echo "base64-encoded-value" | base64 -d
```

**2. Connection Timeout**
```bash
# Test SMTP connectivity from pod
kubectl exec -it deployment/phoenix-web -n phoenixapp -- telnet smtp.sendgrid.net 587
```

**3. TLS/SSL Issues**
```bash
# Check Phoenix logs
kubectl logs -f deployment/phoenix-web -n phoenixapp
```

### Testing SMTP Configuration

Create a test email function in your Phoenix app:
```elixir
# In IEx console
alias PhoenixApp.Mailer
import Swoosh.Email

new()
|> to("test@example.com")
|> from("noreply@rio-tek.com")
|> subject("Test Email")
|> text_body("This is a test email from your Phoenix app!")
|> Mailer.deliver()
```

## Environment Variables Reference

| Variable | Description | Example |
|----------|-------------|---------|
| `SMTP_HOST` | SMTP server hostname | `smtp.sendgrid.net` |
| `SMTP_PORT` | SMTP server port | `587` (TLS) or `465` (SSL) |
| `SMTP_USER` | SMTP username/API key | `apikey` (SendGrid) |
| `SMTP_PASS` | SMTP password/secret | Your API key or password |

## Quick Commands

```bash
# Apply SMTP configuration
kubectl apply -f k3s/overlays/prod/secrets.yaml
kubectl rollout restart deployment/phoenix-web -n phoenixapp

# Check configuration
kubectl describe configmap phoenix-config -n phoenixapp
kubectl get secret phoenix-secrets -n phoenixapp

# View logs
kubectl logs -f deployment/phoenix-web -n phoenixapp | grep -i smtp
```