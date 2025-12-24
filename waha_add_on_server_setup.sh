#!/bin/bash

# waha_server_setup.sh
# This script automates the installation of WAHA (WhatsApp HTTP API) on a VPS.
# It sets up Docker, Docker Compose, Nginx as a reverse proxy, and secures the application with Let's Encrypt SSL.

# --- SERVER IP ---
SERVER_IP=$(ip=$(curl -s ifconfig.me || curl -s icanhazip.com); [[ "$ip" == *:* ]] && echo "[$ip]" || echo "$ip")

# --- Configuration Variables ---
WAHA_PORT="3000" # Default WAHA port, as per documentation
WAHA_DIR="/root/waha" # Directory where WAHA will be installed

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --port)
            WAHA_PORT="$2"
            shift 2
            ;;
        --dir)
            WAHA_DIR="/root/$2"
            shift 2
            ;;
        *)
            error_exit "Unknown option: $1"
            ;;
    esac
done

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

# Check if port is available
check_port_availability() {
    local port="$1"
    if ss -tuln | grep -q ":$port"; then
        error_exit "Port $port is already in use. Please free the port or choose a different one."
    fi
}

# Configure UFW firewall
configure_ufw() {
    log_message "Configuring UFW firewall..."
    
    # Install UFW if not present
    if ! command -v ufw &> /dev/null; then
        apt install -y ufw || error_exit "Failed to install UFW."
    fi
    
    ufw allow $WAHA_PORT || error_exit "Failed to allow $WAHA_PORT through UFW."
	ufw --force enable || error_exit "Failed to enable UFW."
    log_message "UFW configured successfully. Allowed $WAHA_PORT."
}

# Generate strong random string
generate_random_string() {
    openssl rand -base64 32 | tr -dc A-Za-z0-9 | head -c "$1"
}

# --- Main Script ---

check_root

log_message "Starting WAHA Installation Script"

echo ""

# 3. Check port availability
check_port_availability "$WAHA_PORT"

# 4. Generate strong API key and dashboard credentials
log_message "Generating API Key and Dashboard Credentials..."
WAHA_API_KEY=$(generate_random_string 48)
WAHA_DASHBOARD_USERNAME="admin" # Default, can be changed later
WAHA_DASHBOARD_PASSWORD=$(generate_random_string 24)

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
	sed -i "s|'127.0.0.1:3000:3000/tcp'|'$WAHA_PORT:$WAHA_PORT'|" docker-compose.yaml || error_exit "Failed to fix Docker ports configuration."
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
	sed -i "s/^# WHATSAPP_API_PORT=.*/WHATSAPP_API_PORT=$WAHA_PORT/" .env || error_exit "Failed to set WHATSAPP_API_PORT."
	sed -i "s/^# WAHA_APPS_ENABLED=.*/WAHA_APPS_ENABLED=True/" .env || error_exit "Failed to set WAHA_APPS_ENABLED."
	sed -i "s/^# REDIS_URL=.*/REDIS_URL=redis://redis:6379/" .env || error_exit "Failed to set WAHA_APPS_ENABLED."
	sed -i "s|^# TZ=.*|TZ=Asia/Kolkata|" .env || error_exit "Failed to set TZ."
	sed -i "s/^# WHATSAPP_START_SESSION=.*/WHATSAPP_START_SESSION=default/" .env || error_exit "Failed to set WHATSAPP_START_SESSION."
	
	# Updating Dockerfile
	sed -i "s/^EXPOSE 3000/EXPOSE $WAHA_PORT/" Dockerfile || error_exit "Failed to update Dockerfile."
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
echo "WAHA URL: http://$SERVER_IP:$WAHA_PORT"
echo "API Key: $WAHA_API_KEY"
echo "Dashboard Username: $WAHA_DASHBOARD_USERNAME"
echo "Dashboard Password: $WAHA_DASHBOARD_PASSWORD"
echo ""
echo "Important Notes:"
echo "- Keep your API key and dashboard credentials secure"
echo "- Check logs if needed: cd $WAHA_DIR && docker compose logs"
echo "- To restart WAHA: cd $WAHA_DIR && docker compose restart"
echo "================================================================="
