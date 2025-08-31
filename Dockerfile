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
    
    # -------------------------------
    # Install hex and rebar first
    # -------------------------------
    RUN mix local.hex --force && mix local.rebar --force
    
    # -------------------------------
    # Copy config and install deps
    # -------------------------------
    COPY config ./config
    
    # Set temporary env vars for build
    ENV SECRET_KEY_BASE=build_time_secret_key_base_placeholder_64_chars_long_minimum
    ENV LIVE_VIEW_SIGNING_SALT=build_time_salt_32_chars_long_min
    ENV GUARDIAN_SECRET_KEY=build_time_guardian_secret_key_placeholder_64_chars_long_minimum
    
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
    RUN npm run build
    
    WORKDIR /app
    
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
    