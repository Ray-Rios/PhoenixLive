# rust_game/Dockerfile
FROM rust:1.75-slim as builder

# Install system dependencies
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Copy manifest files
COPY Cargo.toml ./

# Create a dummy main.rs to cache dependencies
RUN mkdir src && echo "fn main() {}" > src/main.rs

# Build dependencies (this step is cached if Cargo.toml hasn't changed)
RUN cargo build --release
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

# Copy the binary from builder stage
COPY --from=builder /app/target/release/rust_game_service /app/rust_game_service

# Copy migrations
COPY --from=builder /app/migrations ./migrations

# Change ownership
RUN chown -R app:app /app
USER app

EXPOSE 8080

CMD ["./rust_game_service"]