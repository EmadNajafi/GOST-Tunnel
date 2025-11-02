#!/bin/bash

SERVICE_FILE="/etc/systemd/system/gost.service"
GOST_BIN="/usr/local/bin/gost"
GOST_VER="2.11.1"

function install_gost() {
    echo "Installing dependencies..."
    sudo apt update
    sudo apt install wget nano -y

    echo "Downloading GOST..."
    wget "https://github.com/ginuerzh/gost/releases/download/v${GOST_VER}/gost-linux-amd64-${GOST_VER}.gz" -O "gost.gz"
    gunzip gost.gz
    sudo mv gost-linux-amd64-${GOST_VER} $GOST_BIN
    sudo chmod +x $GOST_BIN

    read -p "Enter local listening port: " LOCAL_PORT
    read -p "Enter destination IP: " DEST_IP
    read -p "Enter destination port: " DEST_PORT

    create_service "$LOCAL_PORT" "$DEST_IP" "$DEST_PORT"

    sudo systemctl daemon-reload
    sudo systemctl enable gost
    sudo systemctl restart gost

    echo "GOST installed and service started."
}

function create_service() {
    local port="$1"
    local ip="$2"
    local dest_port="$3"

    sudo bash -c "cat > $SERVICE_FILE" <<EOL
[Unit]
Description=GO Simple Tunnel
After=network.target
Wants=network.target

[Service]
Type=simple
ExecStart=$GOST_BIN -L=tcp://:${port}/${ip}:${dest_port}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOL
}

function change_tunnel() {
    if [[ ! -f "$SERVICE_FILE" ]]; then
        echo "Service not found. Please install first."
        return
    fi

    read -p "Enter new local listening port: " LOCAL_PORT
    read -p "Enter new destination IP: " DEST_IP
    read -p "Enter new destination port: " DEST_PORT

    create_service "$LOCAL_PORT" "$DEST_IP" "$DEST_PORT"
    sudo systemctl daemon-reload
    sudo systemctl restart gost
    echo "Tunnel updated."
}

function remove_tunnel() {
    sudo systemctl stop gost
    sudo systemctl disable gost
    sudo rm -f "$SERVICE_FILE"
    sudo rm -f "$GOST_BIN"
    sudo systemctl daemon-reload
    echo "GOST and tunnel service removed."
}

function show_menu() {
    echo "===== GOST Tunnel Manager ====="
    echo "1) Install and start tunnel"
    echo "2) Change tunnel IP/Port"
    echo "3) Stop tunnel"
    echo "4) Start tunnel"
    echo "5) Remove tunnel"
    echo "6) Check tunnel status"
    echo "0) Exit"
    read -p "Select an option: " choice

    case $choice in
        1) install_gost ;;
        2) change_tunnel ;;
        3) sudo systemctl stop gost ;;
        4) sudo systemctl start gost ;;
        5) remove_tunnel ;;
        6) sudo systemctl status gost ;;
        0) exit 0 ;;
        *) echo "Invalid option";;
    esac
}

while true; do
    show_menu
done
