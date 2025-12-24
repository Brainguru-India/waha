Use this to initially update the server-
apt update -y && apt upgrade -y && apt autoremove -y && apt autoclean -y && reboot

Use this to initially install WAHA on the Server-
curl -fsSL https://raw.githubusercontent.com/Brainguru-India/waha/refs/heads/main/waha_initial_server_setup.sh | bash -s -- --port 3000 --dir waha-main

Use this to install Add on WAHA Containers on the Server-
curl -fsSL https://raw.githubusercontent.com/Brainguru-India/waha/refs/heads/main/waha_add_on_server_setup.sh | bash -s -- --port 3001 --dir waha-1
