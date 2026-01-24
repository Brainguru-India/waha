Use this to install basic services on the Server (It will be restared at the end)-

curl -fsSL https://raw.githubusercontent.com/Brainguru-India/scripts/refs/heads/main/basic_server_setup.sh | bash

----------------------------------------------------------

Use this to install WAHA Containers on the Server-

curl -fsSL https://raw.githubusercontent.com/Brainguru-India/scripts/refs/heads/main/waha_container_setup.sh | bash -s -- --port 3001 --dir waha-1

----------------------------------------------------------

Use this to install Open WebUI with Nvidia GPU  on the Server-

curl -fsSL https://raw.githubusercontent.com/Brainguru-India/scripts/refs/heads/main/openwebui_with_nvidia_gpu.sh | bash
