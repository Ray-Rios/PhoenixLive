✅ Note: These vars must be generated for prod before deployment otherwise start.sh will fail.
🐛 Place in k3s/overlays/prod/secrets.yaml (copy template from dev and change db password while you're at it)
SECRET_KEY_BASE= $(mix phx.gen.secret 64)
LIVE_VIEW_SIGNING_SALT= $(mix phx.gen.secret 32)
GUARDIAN_SECRET_KEY= $(mix_guardian.gen.secret)

## 🔧 Docker stuff 🔧 ##
docker builder prune -f && ./deploy.sh
docker system prune -a -f
docker volume prune -a -f
docker build --no-cache -t phoenixapp:latest .
docker rmi phoenixapp:latest
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
kubectl describe ingress phoenix-ingress -n phoenixapp"
kubectl logs -n phoenixapp-dev deploy/phoenix-web
kubectl logs -f deployment/phoenix-web -n phoenixapp"
kubectl logs phoenix-web-766545c5d5-4hmfj -n phoenixapp -f
kubectl exec phoenix-web-77fc6746cd-vqc7m -n phoenixapp-dev -- mix ecto.migrate
kubectl cp pvc postgres-pvc -n phoenixapp-dev
kubectl delete pvc postgres-pvc -n phoenixapp-dev
kubectl delete namespace phoenixapp-dev --ignore-not-found=true   #Deletes everything including pvcs

kubectl get configmap phoenix-config -n phoenixapp-dev -o yaml
kubectl get ingress -n phoenixapp-dev -o yaml
kubectl get endpoints phoenix-web -n phoenixapp-dev
kubectl apply -k k3s/overlays/dev
kubectl apply -k k3s/overlays/dev/
docker build --no-cache -t phoenix-app . && kubectl rollout restart deployment/phoenix-web -n phoenixapp

kubectl scale deployment phoenix-web --replicas=0 -n phoenixapp && sleep 5 && kubectl scale deployment phoenix-web --replicas=2 -n phoenixapp
## 🔧 Phoenix stuff 🔧 ##
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


## REDIS ##
docker exec projekt-redis-1 redis-cli MONITOR
# Check specific data types
docker exec projekt-redis-1 redis-cli KEYS "player:*"
docker exec projekt-redis-1 redis-cli KEYS "session:*"
docker exec projekt-redis-1 redis-cli KEYS "leaderboard:*"

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
Get-Process | Where-Object {$_.ProcessName -like "*beam*" -or $_.ProcessName -like "*erl*" -or $_.ProcessName -like "*node*"}

Register a user:
curl -X POST http://localhost/api/auth/register -H "Content-Type: application/json" -d '{"email":"test@example.com","name":"TestUser","password":"SecurePass123!"}'
Verify their email (development only):
curl -X POST http://localhost/api/auth/dev-verify -H "Content-Type: application/json" -d '{"email":"test@example.com"}'
Login successfully:
curl -X POST http://localhost/api/auth/login -H "Content-Type: application/json" -d '{"email":"test@example.com","password":"SecurePass123!"}'

# JS bundled file inspection (used to verify caching issues)
 curl -Ik https://localhost/assets/app.js


AI context:
This project is a kubernetes k3s build. please run commands through kubectl as neccessary. This is a phoenix application with postgres and redis (although not enabled currently). I have a GraphQL layer with an API layer trying to play nice together. For Babylon.js we're using tree-shaken imports and need to make sure we're importing the correctly

AI context: please do no execute migrations in the pods themselves. update the files and re-deploy the kubernetes manifest. We've been down this road before and it causes severe docker issues.


