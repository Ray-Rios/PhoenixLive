# -------------------------------
# Base image
# -------------------------------
    FROM elixir:latest
    # -------------------------------
    # System deps
    # -------------------------------
        RUN apt-get update && apt-get install -y \
        curl \
        git \
        build-essential \
        postgresql-client \
        inotify-tools \
        redis-tools \
        nodejs \
        npm \
        && rm -rf /var/lib/apt/lists/*
    
    # -------------------------------
    # Set workdir & env
    # -------------------------------
    WORKDIR /app
    ARG MIX_ENV=dev
    ENV MIX_ENV=${MIX_ENV}
    
    # -------------------------------
    # Copy deps files for caching
    # -------------------------------
    COPY mix.* ./
    COPY config ./config
    
    # -------------------------------
    # Install deps for all envs
    # -------------------------------
    RUN mix local.hex --force && mix local.rebar --force
    RUN mix deps.get && mix deps.compile
    
    # -------------------------------
    # Copy full app source
    # -------------------------------
    COPY lib ./lib
    COPY priv ./priv
    COPY assets ./assets
    
    # -------------------------------
    # Build assets
    # -------------------------------
    WORKDIR /app/assets
    RUN npm install
    RUN npm install @tailwindcss/forms --save-dev
    RUN npx update-browserslist-db@latest
    
    WORKDIR /app
    RUN mix assets.deploy
    
    # -------------------------------
    # Compile only for prod
    # -------------------------------
    RUN if [ "$MIX_ENV" = "prod" ]; then mix compile; fi
    
    # -------------------------------
    # Expose port & start script
    # -------------------------------
    EXPOSE 4000
    COPY start.sh /usr/local/bin/start.sh
    RUN chmod +x /usr/local/bin/start.sh
    CMD ["/usr/local/bin/start.sh"]
    