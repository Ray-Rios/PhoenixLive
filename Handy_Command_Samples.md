✅ Notes:

kubectl logs phoenix-web-766545c5d5-4hmfj -n phoenixapp -f

Dev setup: vscode, wsl, docker, rancher-desktop, 
kubectl get svc -n ingress-nginx -o wide

SECRET_KEY_BASE, LIVE_VIEW_SIGNING_SALT, and GUARDIAN_SECRET_KEY in prod must be generated.
For prod, you must replace these with real secrets before deployment — otherwise start.sh will fail.
Example:
SECRET_KEY_BASE= $(mix phx.gen.secret 64)
LIVE_VIEW_SIGNING_SALT= $(mix phx.gen.secret 32)
> and then inserted it into .env.prod.

Recommended to run dev first and generate secrets in the web docker container
 > docker-compose web RUN mix phx.gen.secret


#full database dump,create,migration rotation. It's like wiping your ass.
docker compose exec web ./reset_migrations.sh -d
mix phx.server

How it works:
  Dev (docker-compose.yml)
    Bind-mounts your source code.
    MIX_ENV=dev is set by the compose file.
    Assets aren’t precompiled — you can use npm run watch or mix phx.server with watchers inside the container.
    Live code changes reflected immediately.
  Prod (prod.yml)
    No bind-mounts — uses built image.
    MIX_ENV=prod is set via ARG or environment.
    Assets are precompiled with mix assets.deploy.
    Fully compiled and ready to run.
-- --------------------------------------------
 > docker-compose up -d    # dev mode (default)
 > docker-compose -f prod.yml up -d  # prod mode
----------------------------------------------

# For the time when .css doesn't load
# This runs Tailwind/Esbuild, digests assets, and updates the manifest.
MIX_ENV=prod mix assets.deploy

# Mix command to create jwt token for a new api signature
# place in config/dev.exs or prod.exs
docker-compose exec web mix guardian.gen.secret

Rebuild your Docker image and remove old volumes:
In your project directory, run:
  docker-compose down -v --rmi all
  docker-compose build --no-cache
  docker-compose up
  docker-compose run --rm web bash

Tailwind & NPM rebuilding
docker-compose exec web bash -c "cd assets && npx tailwindcss -c tailwind.config.js -i css/app.css -o ../priv/static/assets/app.css --verbose"
docker-compose exec web bash -c "cd assets && npm run build"
                                              npm run build:css
Get-Process | Where-Object {$_.ProcessName -like "*beam*" -or $_.ProcessName -like "*erl*" -or $_.ProcessName -like "*node*"}

prune your docker
docker system prune -a -f
docker volume prune -a -f


# Fix your github Repo
mv -v .git .git_old &&            # Remove old Git files
git init &&                       # Initialise new repository
git remote add origin "${url}" && # Link to old repository
git fetch &&                      # Get old history
# Note that some repositories use 'master' in place of 'main'. Change the following line if your remote uses 'master'.
git reset origin/main --mixed     # Force update to old history.
This leaves your working tree intact, and only affects Git's bookkeeping.


## REDIS ##
docker exec projekt-redis-1 redis-cli MONITOR
# Check specific data types
docker exec projekt-redis-1 redis-cli KEYS "player:*"
docker exec projekt-redis-1 redis-cli KEYS "session:*"
docker exec projekt-redis-1 redis-cli KEYS "leaderboard:*"

## Phoenix stuff ##
mix deps.get
mix compile
mix ecto.create
mix ecto.migrate
mix phx.server

## CockroachDB ##
cockroach start-single-node --insecure --listen-addr=0.0.0.0 --http-addr=0.0.0.0 --store=/cockroach/cockroach-data

🌐 Quick Test Links:
Pixel Streaming: http://localhost:9070
eqemuue5: http://localhost:7000
Phoenix App: http://localhost:4000
Services Status: http://localhost:4000/admin/services
Streaming Status: http://localhost:9070/status
View cockroach database admin at http://localhost:8081
Test mailhog emails at http://localhost:8025

📡 API Endpoints:
GraphQL: http://localhost:4000/api/graphql
GraphiQL: http://localhost:4000/api/graphiql (dev only)

# Test the API endpoint directly
curl http://localhost:9070/api/players
curl http://localhost:9070/status