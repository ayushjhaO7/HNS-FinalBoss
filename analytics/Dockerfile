# =============================================================================
#  Dockerfile — R Analytics Service
#  Cold-Chain Vaccine & Medicine Logistics Tracker
# =============================================================================
#
#  Base image: rocker/r-base (official R Docker image)
#  Purpose:    Runs the spoilage risk analysis script on a cron schedule
#
#  The entrypoint script runs analytics.R every 5 minutes in a loop,
#  simulating a cron job without needing a full cron daemon.
# =============================================================================

FROM rocker/shiny:latest

# Install system dependencies for spatial mapping (Leaflet) and databases
RUN apt-get update && apt-get install -y --no-install-recommends \
    libsqlite3-dev \
    libgdal-dev \
    libgeos-dev \
    libproj-dev \
    libudunits2-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    libfontconfig1-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy and install R dependencies first (for Docker layer caching)
COPY install_packages.R .
RUN Rscript install_packages.R


# Copy the analytics script
COPY analytics.R .

# Create shared data directory
RUN mkdir -p /shared/data

# Environment variables
ENV DB_PATH=/shared/data/telemetry.db
ENV CRON_INTERVAL=300

# Expose port and run the Shiny app
EXPOSE 3838
CMD ["R", "-e", "shiny::runApp('/app/analytics.R', port=3838, host='0.0.0.0')"]
