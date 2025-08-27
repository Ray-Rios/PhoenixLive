FROM elixir:1.15.7-otp-26

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    build-essential \
    postgresql-client \
    redis-tools \
    inotify-tools \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js for asset compilation
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y nodejs

# Install Hex and Rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set working directory
WORKDIR /app

# Set environment early
ENV MIX_ENV=dev

# Copy application code
COPY . .

# Copy and make startup script executable
COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

# Install dependencies (this will generate mix.lock)
RUN mix deps.get

# Create necessary directories
RUN mkdir -p priv/static/assets

# Copy assets over
COPY assets priv/static/assets

# Compile the application
RUN mix compile

# Expose ports
EXPOSE 4000

# Start the Phoenix server with proper wait conditions
CMD ["/usr/local/bin/start.sh"]