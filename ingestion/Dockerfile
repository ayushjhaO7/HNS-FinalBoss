# =============================================================================
#  Dockerfile — PySpark Data Ingestion Service
#  Cold-Chain Vaccine & Medicine Logistics Tracker
# =============================================================================
#
#  Base image: Python 3.11 slim (lightweight, fast build)
#  Purpose:    Runs the MQTT-to-SQLite ingestion pipeline
#
#  NOTE: Uses python:3.11-slim instead of bitnami/spark for faster builds
#  and lower memory usage. PySpark runs in local mode within this container.
#
# =============================================================================

FROM python:3.11-slim

# Install Java (required for PySpark) and system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    default-jre-headless \
    && rm -rf /var/lib/apt/lists/*

# Set Java environment
ENV JAVA_HOME=/usr/lib/jvm/default-java

# Set working directory
WORKDIR /app

# Copy and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the ingestion script
COPY ingestion.py .

# Create shared data directories
RUN mkdir -p /shared/data /shared/checkpoints

# Environment variables (can be overridden in docker-compose)
ENV MQTT_BROKER=mosquitto
ENV MQTT_PORT=1883
ENV MQTT_TOPIC=coldchain/telemetry/#
ENV DATA_DIR=/shared/data
ENV CHECKPOINT_DIR=/shared/checkpoints
ENV BATCH_INTERVAL=30

# Run the ingestion pipeline
CMD ["python", "/app/ingestion.py"]
