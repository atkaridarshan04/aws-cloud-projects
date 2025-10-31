#!/bin/bash -ex

# Variables will be injected by Terraform
YOUR_DEFAULT_AWS_REGION="${default_aws_region}"
IMAGES_BUCKET="${images_bucket}"
YOUR_DYNAMODB_TABLE_NAME="${dynamodb_table_name}"

# Update apt and install required tools
apt -y update
apt -y install unzip stress

# Install Node.js using nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh | bash

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

nvm install 20

# Create application directory
mkdir -p /var/app

# Get the app and extract it
wget https://raw.githubusercontent.com/atkaridarshan04/aws-3tier-ha-app/main/app.zip
unzip app.zip -d /var/app/

# Navigate into the application directory
cd /var/app/

# Configure environment variables using the injected values
export PHOTOS_BUCKET=$IMAGES_BUCKET
export DEFAULT_AWS_REGION=$YOUR_DEFAULT_AWS_REGION
export TABLE_NAME=$YOUR_DYNAMODB_TABLE_NAME
export SHOW_ADMIN_TOOLS=1

# Install npm dependencies
npm install

# Start the application using a process manager like pm2 for production environments
# This ensures the app runs in the background and restarts on failure
# apt -y install npm install -g pm2
# pm2 start index.js --name "EmployeeManagementApp"

# For simple demonstration, you can use `npm start`, but be aware it will block the script.
npm start