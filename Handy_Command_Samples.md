✅ Note: These vars must be generated for prod before deployment otherwise start.sh will fail.
🐛 Place in k3s/overlays/prod/secrets.yaml (copy template from dev and change db password while you're at it)
SECRET_KEY_BASE= $(mix phx.gen.secret 64)
LIVE_VIEW_SIGNING_SALT= $(mix phx.gen.secret 32)
GUARDIAN_SECRET_KEY= $(mix_guardian.gen.secret)

## 🔧 Docker stuff 🔧 ##
# Recommended: Phoenix-specific cleanup only
./cleanup-docker.sh phoenix

# Preview what will be cleaned
./cleanup-docker.sh preview

# Clean containers only (keeps images/volumes)
./cleanup-docker.sh containers

# Nuclear option (destroys everything - requires confirmation)
./cleanup-docker.sh nuclear

# Manual selective cleanup commands:
docker images --filter=reference="phoenixapp*" -q | xargs -r docker rmi -f  # Remove Phoenix images only
docker container prune -f  # Remove stopped containers
docker image prune -f      # Remove dangling images
docker builder prune -f    # Clean build cache

# Old destructive commands (use with caution):
docker builder prune -f && ./deploy.sh
docker system prune -a -f
docker volume prune -a -f
docker build --no-cache -t phoenixapp:latest .
docker rmi phoenixapp:latest
docker build -t phoenixapp:prod --progress=plain --build-arg MIX_ENV=prod
docker system prune -a -f && docker volume prune -f && docker builder prune -f
docker system prune --volume
## 🔧 Kube stuff 🔧 ##
kubectl get pods -n phoenixapp-dev
kubectl get pvc -n phoenixapp-dev
kubectl get events -n phoenixapp-dev --sort-by='.metadata.creationTimestamp' | tail -n 20
kubectl get all -n phoenixapp"
kubectl get certificates -n phoenixapp"
kubectl get svc -n ingress-nginx -o wide
kubectl describe deployment phoenix-web -n phoenixapp-dev
kubectl describe ingress phoenix-ingress -n phoenixapp
kubectl logs -n phoenixapp-dev deploy/phoenix-web
kubectl logs phoenix-web-766545c5d5-4hmfj -n phoenixapp -f
kubectl exec phoenix-web-77fc6746cd-vqc7m -n phoenixapp-dev -- mix ecto.migrate
kubectl cp pvc postgres-pvc -n phoenixapp-dev
kubectl delete pvc postgres-pvc -n phoenixapp-dev
kubectl logs -f deployment/phoenix-web -n phoenixapp   # -f follow logs
kubectl logs -n phoenixapp -l app=phoenix-web -f

kubectl delete namespace phoenixapp-dev --ignore-not-found=true   #Deletes everything including pvcs
kubectl delete namespace phoenixapp --ignore-not-found=true && docker system prune -a -f --volumes && ./deploy-prod.sh

kubectl get configmap phoenix-config -n phoenixapp-dev -o yaml
kubectl get ingress -n phoenixapp-dev -o yaml
kubectl get endpoints phoenix-web -n phoenixapp-dev
kubectl apply -k k3s/overlays/dev
docker build --no-cache -t phoenix-app . && kubectl rollout restart deployment/phoenix-web -n phoenixapp
kubectl rollout restart deployment/phoenix-web -n phoenixapp

kubectl scale deployment phoenix-web --replicas=0 -n phoenixapp && sleep 5 && kubectl scale deployment phoenix-web --replicas=2 -n phoenixapp


Run Migrations
MSYS_NO_PATHCONV=1 kubectl exec -n phoenixapp \
  $(kubectl get pods -n phoenixapp -l app=phoenix-web -o name | head -1) \
  -- /app/bin/phoenix_app eval "PhoenixApp.Release.migrate()"

## 🔧 Phoenix stuff 🔧 ##
# PostgreSQL Operations Script
./postgres-ops.sh backup                # Backup PostgreSQL database
./postgres-ops.sh restore               # Choose from backup list and restore
./postgres-ops.sh list                  # Show all available backups
./postgres-ops.sh clean                 # Remove old backups (keep 10)
./postgres-ops.sh connect               # Connect to PostgreSQL shell
./postgres-ops.sh size                  # Show database sizes
./postgres-ops.sh logs                  # Show PostgreSQL logs

# Phoenix commands
mix clean
mix deps.clean --all
mix deps.get
mix compile
mix ecto.drop
mix ecto.create
mix ecto.migrate
mix phx.server
mix assets.deploy  # For the time when .css doesn't load

pkill -f "mix phx.server"
  echo "✅ Phoenix server stopped."


# Fix your github Repo
mv -v .git .git_old               # Remove old Git files
git init                          # Initialise new repository
git remote add origin "${url}"    # Link to old repository
git fetch                         # Get old history
git reset origin/master --mixed     # Force update to old history.
# Note that some repositories use 'master' in place of 'main'. Change the following line if your remote uses 'master'.
# This leaves your working tree intact, and only affects Git's bookkeeping.

## File corruption fix ##
rm file_name.ts && touch file_name.ts

## REDIS ##
# Redis Operations Script
./redis-ops.sh backup                    # Backup Redis data
./redis-ops.sh restore                   # Restore latest backup
./redis-ops.sh monitor                   # Monitor all Redis commands
./redis-ops.sh keys "chat:*"            # Show chat-related keys
./redis-ops.sh keys "player:*"          # Show player-related keys
./redis-ops.sh keys "session:*"         # Show session keys
./redis-ops.sh flush                     # DANGEROUS: Delete all data


🌐 Quick Test Links:
Phoenix App: http://localhost:4000
Services Status: http://localhost:4000/admin/services

Test mailhog emails at http://localhost:8025

📡 API Endpoints:
GraphQL: http://localhost:4000/api/graphql
GraphiQL: http://localhost:4000/api/graphiql (dev only)

Tailwind & NPM rebuilding
docker-compose exec web bash -c "cd assets && npx tailwindcss -c tailwind.config.js -i css/app.css -o ../priv/static/assets/app.css --verbose"
docker-compose exec web bash -c "cd assets && npm run build"
                                              npm run build:css

# Update browserslist database (fixes caniuse-lite warnings)
./scripts/dev-assets.sh run update-browserslist

Get-Process | Where-Object {$_.ProcessName -like "*beam*" -or $_.ProcessName -like "*erl*" -or $_.ProcessName -like "*node*"}

Register a user:
curl -X POST http://localhost/api/auth/register -H "Content-Type: application/json" -d '{"email":"test@example.com","name":"TestUser","password":"SecurePass123!"}'
Verify their email (development only):
curl -X POST http://localhost/api/auth/dev-verify -H "Content-Type: application/json" -d '{"email":"test@example.com"}'
Login successfully:
curl -X POST http://localhost/api/auth/login -H "Content-Type: application/json" -d '{"email":"test@example.com","password":"SecurePass123!"}'

# JS bundled file inspection (used to verify caching issues)
 curl -Ik https://localhost/assets/app.js

# Debugging commands to verify JavaScript/LiveSocket execution
# 1) Check for LiveView console log in browser: should see "✅ Phoenix LiveView connected"
# 2) Check for WebSocket upgrade in Network -> WS, or use curl to verify Upgrade headers via the ingress/backend
# 3) Tail Phoenix logs to see joins and channel debugging
kubectl logs -n phoenixapp -l app=phoenix-web -f | grep -i "phx_join" --line-buffered


AI context:
This project is a kubernetes k3s build. please run commands through kubectl as neccessary. This is a phoenix application with postgres and redis. I have an API layer so I can extend this program outside this applicaiton.

AI context: please do no execute migrations in the pods themselves. update the files and re-deploy the kubernetes manifest. We've been down this road before and it causes severe docker issues.


kubectl apply -k k3s/overlays/prod/
kubectl rollout restart deployment/phoenix-web -n phoenixapp