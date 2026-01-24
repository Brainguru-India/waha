#!/bin/bash

# waha_server_setup.sh
# This script automates the installation of WAHA (WhatsApp HTTP API) on a VPS.
# It sets up Docker, Docker Compose, Nginx as a reverse proxy, and secures the application with Let's Encrypt SSL.

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

# --- Main Script ---

check_root

# 5. Install system dependencies
log_message "Installing system dependencies..."
apt update -y && apt upgrade -y && apt autoremove -y && apt autoclean -y || error_exit "Failed to update basic services."
apt install -y curl wget gnupg2 lsb-release net-tools || error_exit "Failed to install system dependencies."

# 6. Install Git
install_git

# 7. Install Docker and Docker Compose
install_docker

# 8. Reboot
reboot
