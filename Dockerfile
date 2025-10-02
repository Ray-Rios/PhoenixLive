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

        # -------------------------------    
        # Set temporary build args and env vars for compilation
        # -------------------------------
            ARG SECRET_KEY_BASE=build_time_secret_key_base_placeholder_64_chars_long_minimum
            ARG LIVE_VIEW_SIGNING_SALT=build_time_salt_32_chars_long_min
            ARG GUARDIAN_SECRET_KEY=build_time_guardian_secret_key_placeholder_64_chars_long_minimum
            
            # Set environment variables from build args for compilation only
            ENV SECRET_KEY_BASE=${SECRET_KEY_BASE}
            ENV LIVE_VIEW_SIGNING_SALT=${LIVE_VIEW_SIGNING_SALT}
            ENV GUARDIAN_SECRET_KEY=${GUARDIAN_SECRET_KEY}
            
            RUN mix deps.get && mix deps.compile
            
        # -------------------------------
        # Copy source code and compile - $(date)
        # -------------------------------
            COPY lib ./lib
            COPY priv ./priv
            
        # -------------------------------
        # Copy assets and build them
        # -------------------------------
            COPY assets ./assets
            RUN cd assets && \
                npm config set fetch-retry-mintimeout 20000 && \
                npm config set fetch-retry-maxtimeout 120000 && \
                npm config set fetch-retries 5 && \
                npm config set registry https://registry.npmjs.org/ && \
                npm cache clean --force && \
                npm install --prefer-offline --no-audit --no-fund
            
            # Build assets based on environment
            RUN if [ "$MIX_ENV" = "prod" ]; then \
                mix assets.deploy; \
            else \
                mix assets.build; \
            fi
            
            RUN mix compile
            
        # -------------------------------
        # Build release for production
        # -------------------------------
            RUN if [ "$MIX_ENV" = "prod" ]; then \
                mix release; \
            fi
        
    # -------------------------------
    # Expose port & start script
    # -------------------------------
    EXPOSE 4000
    COPY phx-start.sh /usr/local/bin/phx-start.sh
    RUN chmod +x /usr/local/bin/phx-start.sh
    
    CMD ["/usr/local/bin/phx-start.sh"]
                    