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
        # Copy pre-compiled assets
        # -------------------------------
            COPY priv/static ./priv/static
                    
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

        # -------------------------------    
        # Set temporary env vars for build
        # -------------------------------
            ENV SECRET_KEY_BASE=build_time_secret_key_base_placeholder_64_chars_long_minimum
            ENV LIVE_VIEW_SIGNING_SALT=build_time_salt_32_chars_long_min
            ENV GUARDIAN_SECRET_KEY=build_time_guardian_secret_key_placeholder_64_chars_long_minimum
            
            RUN mix deps.get && mix deps.compile
            
        # -------------------------------
        # Copy source code and compile
        # -------------------------------
            COPY lib ./lib
            
        # -------------------------------
        # Copy assets and build them
        # -------------------------------
            COPY assets ./assets
            RUN cd assets && npm install
            RUN mix assets.deploy
            
            RUN mix compile
        
    # -------------------------------
    # Expose port & start script
    # -------------------------------
    EXPOSE 4000
    COPY start.sh /usr/local/bin/start.sh
    RUN chmod +x /usr/local/bin/start.sh
    CMD ["/usr/local/bin/start.sh"]
                    