FROM elixir:latest

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

# Install PowerShell
RUN wget -q "https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb" -O packages-microsoft-prod.deb \
    && dpkg -i packages-microsoft-prod.deb \
    && apt-get update \
    && apt-get install -y powershell \
    && rm packages-microsoft-prod.deb


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

# Install frontend dependencies (npm)
WORKDIR /app/assets
RUN npm install
RUN npm install @tailwindcss/forms --save-dev
RUN npx update-browserslist-db@latest

# Build frontend assets
WORKDIR /app
RUN npm run --prefix ./assets build

# Create necessary directories
RUN mkdir -p priv/static/assets

# Compile the application
RUN mix compile

# Build frontend assets (JS/CSS) into priv/static
RUN mix assets.build

# Expose ports
EXPOSE 4000

# Start the Phoenix server with proper wait conditions
CMD ["/usr/local/bin/start.sh"]