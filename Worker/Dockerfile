# Use the official Python image
FROM python:3

# Set build time environment variable
ARG BUILD_DATE
ENV BUILD_DATE=$BUILD_DATE
ENV PYTHONUNBUFFERED=1
ENV IN_DOCKER=1

# Set the working directory
# WORKDIR /app
WORKDIR /usr/src/app

# Install PostgreSQL, cron libraries
RUN apt-get update && apt-get install -y \
    build-essential \
    libpq-dev
#    \
#    cron

# \
#& rm -rf /var/lib/apt/lists/*

# Create a virtual environment
# RUN python -m venv /opt/venv

# Activate the virtual environment
# ENV PATH="/opt/venv/bin:$PATH"

# Copy the requirements file from the root directory and prep
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of your application code
COPY /python/src .

# Create the data directory
RUN mkdir -p data

COPY /data/Club_Locations.csv data/

# Firebase credentials are provided via FIREBASE_CREDENTIALS environment variable
# for security reasons (not committed to git)

# Install cron
#RUN apt-get update && apt-get install -y cron

# Add your crontab file in the cron directory
#COPY /python/etc/crontab /etc/cron.d/my-crontab

# Give execution rights on the cron job
#RUN chmod 0644 /etc/cron.d/my-crontab

# Apply cron job
#RUN crontab /etc/cron.d/my-crontab

# Create the log file to be able to run tail
#RUN touch /var/log/cron.log


# Run the complete workflow on container startup
CMD ["python", "process_and_deploy.py"]
