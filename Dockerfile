# Use an official lightweight Ubuntu base image to support both Node.js and Python packages
FROM ubuntu:22.04

# Prevent interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies: Node.js, Python 3, Tesseract OCR, and Poppler (for PDF processing)
RUN apt-get update && apt-get install -y \
    curl \
    python3 \
    python3-pip \
    python3-dev \
    tesseract-ocr \
    poppler-utils \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install n8n globally via npm
RUN npm install n8n -g

# Set up working directory for your Python app
WORKDIR /app

# Copy Python requirements and install dependencies
COPY requirements.txt .
RUN pip3 install --no-cache-dir -r requirements.txt

# Copy your Python application files (e.g., app.py) into the container
COPY . .

# Expose Render's default web port (Render automatically maps PORT environment variable)
EXPOSE 10000

# Create a startup script to run both Flask and n8n concurrently
RUN echo '#!/bin/bash\npython3 app.py &\nn8n start' > /start.sh \
    && chmod +x /start.sh

# Run the startup script
CMD ["/start.sh"]
