Use this to install basic services on the Server-

curl -fsSL https://raw.githubusercontent.com/Brainguru-India/waha/refs/heads/main/waha_basic_server_setup.sh | bash

----------------------------------------------------------

Use this to install WAHA Containers on the Server-

curl -fsSL https://raw.githubusercontent.com/Brainguru-India/waha/refs/heads/main/waha_container_setup.sh | bash -s -- --port 3001 --dir waha-1

----------------------------------------------------------

Use this to install WAHA Container with Chatwoot on the Server-

curl -fsSL https://raw.githubusercontent.com/Brainguru-India/waha/refs/heads/main/waha_container_with_chatwoot_setup.sh | bash -s -- --port 3000 --chatwoot 3009 --dir waha
