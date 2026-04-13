# ==========================================
# STAGE 1: Build Stage
# ==========================================
FROM rust:1.76-slim-bookworm as builder

WORKDIR /usr/src/app

# Install build dependencies
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy manifest and dummy main for dependency caching
COPY Cargo.toml ./
RUN mkdir src && echo "fn main() {}" > src/main.rs
RUN cargo build --release

# Copy actual source code
COPY src ./src
RUN rm -f target/release/deps/coldchain_rust_bridge*
RUN cargo build --release

# ==========================================
# STAGE 2: Runtime Stage
# ==========================================
FROM debian:bookworm-slim

WORKDIR /app

# Install runtime dependencies (minimal)
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# Copy binary from builder
COPY --from=builder /usr/src/app/target/release/coldchain_rust_bridge /app/rust-ingestor

# Create shared data directory
RUN mkdir -p /shared/data

# Entry point
CMD ["./rust-ingestor"]
