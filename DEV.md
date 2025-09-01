✅ Notes:
SECRET_KEY_BASE, LIVE_VIEW_SIGNING_SALT, and GUARDIAN_SECRET_KEY in prod must be generated.
For prod, you must replace these with real secrets before deployment — otherwise start.sh will fail.
Example:
SECRET_KEY_BASE= $(mix phx.gen.secret 64)
LIVE_VIEW_SIGNING_SALT= $(mix phx.gen.secret 32)


and then inserted into .env.prod.

Recommended to run dev first and generate secrets in the web docker container
 > docker-compose web RUN mix phx.gen.secret


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


docker-compose build web

docker-compose run --rm web bash

Tailwind & NPM rebuilding
docker-compose exec web bash -c "cd assets && npx tailwindcss -c tailwind.config.js -i css/app.css -o ../priv/static/assets/app.css --verbose"
docker-compose exec web bash -c "cd assets && npm run build"
                                              npm run build:css
Get-Process | Where-Object {$_.ProcessName -like "*beam*" -or $_.ProcessName -like "*erl*" -or $_.ProcessName -like "*node*"}

prune your docker
docker system prune -a -f


# Restart just the pixel streaming service
docker-compose restart pixel_streaming

# Or rebuild and restart if you made changes
docker-compose up --build pixel_streaming

# Check if the pixel streaming service is running
docker-compose ps pixel_streaming

# Check the logs
docker-compose logs pixel_streaming

# Test the API endpoint directly
curl http://localhost:9070/api/players
curl http://localhost:9070/status


Example Migrations
# Users table
mix ecto.gen.migration create_users
# Posts table
mix ecto.gen.migration create_posts
# Comments table
mix ecto.gen.migration create_comments

#create_users (migration)
defmodule PhoenixApp.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :email, :string, null: false
      add :hashed_password, :string, null: false
      add :role, :string, default: "user"
      timestamps()
    end

    create unique_index(:users, [:email])
  end
end

#create_posts (migration)
defmodule PhoenixApp.Repo.Migrations.CreatePosts do
  use Ecto.Migration

  def change do
    create table(:posts) do
      add :user_id, references(:users), null: false
      add :title, :string, null: false
      add :body, :text
      timestamps()
    end

    create index(:posts, [:user_id])
  end
end

# create_comments (migration)
defmodule PhoenixApp.Repo.Migrations.CreateComments do
  use Ecto.Migration

  def change do
    create table(:comments) do
      add :post_id, references(:posts), null: false
      add :user_id, references(:users), null: false
      add :body, :text
      timestamps()
    end

    create index(:comments, [:post_id])
    create index(:comments, [:user_id])
  end
end

mix ecto.create
mix ecto.migrate

cockroach start-single-node --insecure --listen-addr=0.0.0.0 --http-addr=0.0.0.0 --store=/cockroach/cockroach-data



Open UE5 and load your project
Enable Pixel Streaming Plugin:
Edit → Plugins → Search "Pixel Streaming" → Enable
Package for Linux:
File → Package Project → Linux (x86_64)
Choose output directory: C:\PROJEKT\rust_game\Packaged
The container will automatically pick up the packaged game
🌐 Quick Test Links:
Pixel Streaming: http://localhost:9070
Game Service: http://localhost:9069
Phoenix App: http://localhost:4000
Services Status: http://localhost:4000/admin/services
Streaming Status: http://localhost:9070/status


🚀 Next Steps:
Close UE5 Editor (if open)
Right-click ActionRPGMultiplayerStart.uproject → Generate Visual Studio project files
Open the .sln file in Visual Studio
Build the project (Ctrl+Shift+B)
Open UE5 Editor
Click Play to test