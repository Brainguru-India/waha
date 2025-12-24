#!/bin/bash

# waha_server_setup.sh
# This script automates the installation of WAHA (WhatsApp HTTP API) on a VPS.
# It sets up Docker, Docker Compose, Nginx as a reverse proxy, and secures the application with Let's Encrypt SSL.

# --- SERVER IP ---
SERVER_IP=$(curl -s ifconfig.me/ip || curl -s icanhazip.com)

# --- Configuration Variables ---
WAHA_DIR="/root/waha" # Directory where WAHA will be installed
WAHA_PORT="3000" # Default WAHA port, as per documentation

# --- Functions ---

# Function to display messages
log_message() {
    echo "--- $1 ---"
}

# Function to display errors and exit
error_exit() {
    echo "ERROR: $1" >&2
    exit 1
}

# Function to display warnings
warn_message() {
    echo "WARNING: $1" >&2
}

# Check if script is run as root or with sudo
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error_exit "This script must be run with sudo or as root."
    fi
}

# Install Git
install_git() {
    log_message "Installing Git..."
    apt install -y git || error_exit "Failed to install Git."
    log_message "Git installed successfully."
}

# Install Docker and Docker Compose
install_docker() {
    log_message "Installing Docker and Docker Compose..."

    # Update package list
    apt update || error_exit "Failed to update package list."

    # Install necessary packages for Docker
    apt install -y apt-transport-https ca-certificates curl software-properties-common || error_exit "Failed to install Docker prerequisites."

    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg || error_exit "Failed to add Docker GPG key."

    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null || error_exit "Failed to add Docker repository."

    # Update package list again after adding Docker repo
    apt update || error_exit "Failed to update package list after adding Docker repo."

    # Install Docker Engine
    apt install -y docker-ce docker-ce-cli containerd.io || error_exit "Failed to install Docker Engine."

    # Install Docker Compose (using the plugin method for newer versions)
    apt install -y docker-compose-plugin || error_exit "Failed to install Docker Compose plugin."

    # Start and enable Docker service
    systemctl start docker || error_exit "Failed to start Docker service."
    systemctl enable docker || error_exit "Failed to enable Docker service."

    # Verify Docker installation
    docker run hello-world || error_exit "Docker installation failed. 'hello-world' test failed."

    # Add current user to docker group to run docker commands without sudo
    # Fixed typo: usermerm -> usermod
    if [ -n "$SUDO_USER" ]; then
        usermod -aG docker "$SUDO_USER" || error_exit "Failed to add $SUDO_USER to docker group."
        log_message "Added $SUDO_USER to docker group."
    fi
    
    if [ "$USER" != "root" ]; then
        usermod -aG docker "$USER" || error_exit "Failed to add current user to docker group."
    fi

    log_message "Docker and Docker Compose installed successfully."
    echo "Please log out and log back in (or run 'newgrp docker') for Docker group changes to take effect."
    sleep 3
}

# Configure UFW firewall
configure_ufw() {
    log_message "Configuring UFW firewall..."
    
    # Install UFW if not present
    if ! command -v ufw &> /dev/null; then
        apt install -y ufw || error_exit "Failed to install UFW."
    fi
    
	sed -i "s|IPV6=yes|IPV6=no|" /etc/default/ufw || error_exit "Failed to fix ufw IPV6 configuration."
	ufw reload || error_exit "Failed to reload UFW."
    ufw allow OpenSSH || error_exit "Failed to allow OpenSSH through UFW."
    ufw allow 3000 || error_exit "Failed to allow 3000 through UFW."
	ufw --force enable || error_exit "Failed to enable UFW."
    log_message "UFW configured successfully. Allowed OpenSSH and 3000."
}

# Generate strong random string
generate_random_string() {
    openssl rand -base64 32 | tr -dc A-Za-z0-9 | head -c "$1"
}

# --- Main Script ---

check_root

log_message "Starting WAHA Installation Script"

echo ""

# 4. Generate strong API key and dashboard credentials
log_message "Generating API Key and Dashboard Credentials..."
WAHA_API_KEY=$(generate_random_string 48)
WAHA_DASHBOARD_USERNAME="admin" # Default, can be changed later
WAHA_DASHBOARD_PASSWORD=$(generate_random_string 24)

# 5. Install system dependencies
log_message "Installing system dependencies..."
apt update || error_exit "Failed to update package list."
apt install -y curl wget gnupg2 lsb-release net-tools || error_exit "Failed to install system dependencies."

# 6. Install Git
install_git

# 7. Install Docker and Docker Compose
install_docker

# 8. Install Nginx
install_nginx

# 9. Configure UFW
configure_ufw

# 10. Clone WAHA repository
log_message "Cloning WAHA repository..."
if [ -d "$WAHA_DIR" ]; then
    warn_message "WAHA directory already exists. Removing it..."
    rm -rf "$WAHA_DIR" || error_exit "Failed to remove existing WAHA directory."
fi

mkdir -p "$WAHA_DIR" || error_exit "Failed to create WAHA directory."
git clone https://github.com/devlikeapro/waha.git "$WAHA_DIR" || error_exit "Failed to clone WAHA repository."
cd "$WAHA_DIR" || error_exit "Failed to change directory to WAHA_DIR."
log_message "WAHA repository cloned."

# Fix Docker image configuration to use correct WAHA image
log_message "Fixing Docker image configuration..."
if [ -f "docker-compose.yaml" ]; then
    # Replace waha-plus image with correct waha:latest image
    sed -i "s|image: devlikeapro/waha-plus|image: devlikeapro/waha:gows|" docker-compose.yaml || error_exit "Failed to fix Docker image configuration."
	sed -i "s|'127.0.0.1:3000:3000/tcp'|'3000:3000'|" docker-compose.yaml || error_exit "Failed to fix Docker ports configuration."
    log_message "Docker image configuration fixed - using devlikeapro/waha:gows"
else
    warn_message "docker-compose.yaml not found, skipping image fix"
fi

# 11. Configure WAHA .env file
log_message "Configuring WAHA .env file..."
if [ ! -f ".env.example" ]; then
    warn_message ".env.example not found. Creating basic .env file..."
    cat <<EOF > .env
# WAHA Configuration
WAHA_API_KEY=$WAHA_API_KEY
WAHA_API_KEY_PLAIN=$WAHA_API_KEY
WAHA_DASHBOARD_USERNAME=$WAHA_DASHBOARD_USERNAME
WAHA_DASHBOARD_PASSWORD=$WAHA_DASHBOARD_PASSWORD
WAHA_PORT=$WAHA_PORT
EOF
else
    cp .env.example .env || error_exit "Failed to copy .env.example to .env."
    
    # Update .env with generated values
    sed -i "s/^WAHA_API_KEY=.*/WAHA_API_KEY=$WAHA_API_KEY/" .env || error_exit "Failed to set WAHA_API_KEY."
	sed -i "/^WAHA_API_KEY=/a WAHA_API_KEY_PLAIN=$WAHA_API_KEY" .env || error_exit "Failed to set WAHA_API_KEY_PLAIN."
    sed -i "s/^WAHA_DASHBOARD_USERNAME=.*/WAHA_DASHBOARD_USERNAME=$WAHA_DASHBOARD_USERNAME/" .env || error_exit "Failed to set WAHA_DASHBOARD_USERNAME."
    sed -i "s/^WAHA_DASHBOARD_PASSWORD=.*/WAHA_DASHBOARD_PASSWORD=$WAHA_DASHBOARD_PASSWORD/" .env || error_exit "Failed to set WAHA_DASHBOARD_PASSWORD."
    sed -i "s/^WHATSAPP_SWAGGER_USERNAME=.*/WHATSAPP_SWAGGER_USERNAME=$WAHA_DASHBOARD_USERNAME/" .env || error_exit "Failed to set WHATSAPP_SWAGGER_USERNAME."
    sed -i "s/^WHATSAPP_SWAGGER_PASSWORD=.*/WHATSAPP_SWAGGER_PASSWORD=$WAHA_DASHBOARD_PASSWORD/" .env || error_exit "Failed to set WHATSAPP_SWAGGER_PASSWORD."
    sed -i "s/^WHATSAPP_DEFAULT_ENGINE=.*/WHATSAPP_DEFAULT_ENGINE=GOWS/" .env || error_exit "Failed to set WHATSAPP_DEFAULT_ENGINE."
	sed -i 's|^WAHA_BASE_URL=.*|# &|' .env || error_exit "Failed to unset WAHA_BASE_URL."
	sed -i "s/^# WAHA_APPS_ENABLED=.*/WAHA_APPS_ENABLED=True/" .env || error_exit "Failed to set WAHA_APPS_ENABLED."
	sed -i "/^WAHA_APPS_ENABLED=/a WAHA_APPS_ON=calls" .env || error_exit "Failed to set WAHA_APPS_ON."
	sed -i "s|^# TZ=.*|TZ=Asia/Kolkata|" .env || error_exit "Failed to set TZ."
	sed -i "s/^# WHATSAPP_START_SESSION=.*/WHATSAPP_START_SESSION=default/" .env || error_exit "Failed to set WHATSAPP_START_SESSION."
	
    # Set port if not already set
    if ! grep -q "WAHA_PORT" .env; then
        echo "WAHA_PORT=$WAHA_PORT" >> .env || error_exit "Failed to add WAHA_PORT to .env."
    fi
fi

log_message "WAHA .env file configured."

# 12. Start WAHA containers
log_message "Starting WAHA Docker containers..."
docker compose up -d || error_exit "Failed to start WAHA containers with Docker Compose."

log_message "WAHA installation completed successfully!"
echo ""
echo "================================================================="
echo "WAHA Installation Summary"
echo "================================================================="
echo "WAHA URL: https://$SERVER_IP:$WAHA_PORT"
echo "API Key: $WAHA_API_KEY"
echo "Dashboard Username: $WAHA_DASHBOARD_USERNAME"
echo "Dashboard Password: $WAHA_DASHBOARD_PASSWORD"
echo ""
echo "Important Notes:"
echo "- Keep your API key and dashboard credentials secure"
echo "- Check logs if needed: cd $WAHA_DIR && docker compose logs"
echo "- To restart WAHA: cd $WAHA_DIR && docker compose restart"
echo "================================================================="
