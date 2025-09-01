# Build stage
FROM rust:1.82-slim as builder

# Install system dependencies
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy Cargo files for dependency caching
COPY Cargo.toml ./

# Create dummy main.rs for dependency compilation
RUN mkdir src && echo "fn main() {}" > src/main.rs

# Build dependencies
RUN cargo build --release

# Remove dummy main.rs
RUN rm src/main.rs

# Copy source code
COPY src ./src
COPY migrations ./migrations

# Build the application
RUN touch src/main.rs && cargo build --release

# Runtime stage
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libpq5 \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# Create app user
RUN useradd -m -u 1000 app

WORKDIR /app

# Copy binary and migrations
COPY --from=builder /app/target/release/rust_game_service /app/rust_game_service
COPY --from=builder /app/migrations ./migrations

# Set ownership
RUN chown -R app:app /app

USER app

EXPOSE 8080

CMD ["./rust_game_service"]