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
```[cite: 7]

### 2. Update Your Python App (`app.py`) for Single-Container Networking
Because both n8n and Flask will run inside the exact same container, they can talk to each other locally via `localhost`. 

* Update your Flask port configuration in `app.py` so it doesn't conflict with n8n (n8n usually defaults to port 5678, while Render assigns an external port via the `PORT` environment variable). 
* It is easiest to run Flask on an internal port (like `5000`) inside the container since Render routes traffic directly into your container's exposed port. In your n8n workflow's HTTP Request node, you can now point directly to `http://localhost:5000/convert-slides` instead of using `host.docker.internal` or external URLs[cite: 7].

### 3. Deploying to Render
1. Push your code repository (including the `Dockerfile` and `app.py`) to GitHub.
2. In Render, create a new **Web Service** and connect your GitHub repository.
3. Under **Runtime**, select **Docker** (Render will automatically detect your `Dockerfile`).
4. Set your environment variables in the Render dashboard (such as your Google Sheets credentials or webhook secrets). 
5. Hit **Deploy**. Render will build the image with Tesseract, Python, and n8n combined, launching everything in one unified service.