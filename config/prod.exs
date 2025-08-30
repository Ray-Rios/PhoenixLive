# ----------------------------
# Phoenix Environment
# ----------------------------
MIX_ENV=prod
SECRET_KEY_BASE=GENERATE_WITH_mix_phx.gen.secret
LIVE_VIEW_SIGNING_SALT=GENERATE_WITH_mix_phx.gen.secret
GUARDIAN_SECRET_KEY=GENERATE_WITH_mix_phx.gen.secret

# ----------------------------
# Cockroach Database
# ----------------------------
DB_USERNAME=root
DB_PASSWORD=cockroachDB
DB_HOST=db
DB_PORT=26257
DB_NAME=phoenixlive_prod

# ----------------------------
# Redis
# ----------------------------
REDIS_URL=redis://redis:6379/0

# ----------------------------
# Mail (real SMTP)
# ----------------------------
SMTP_RELAY=smtp.yourprovider.com
SMTP_PORT=587
SMTP_USERNAME=your_username
SMTP_PASSWORD=your_password

# ----------------------------
# CORS (prod)
# ----------------------------
CORS_ALLOWED_ORIGINS=https://yourdomain.com,https://api.yourdomain.com
