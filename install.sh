#!/bin/bash

# Check if the user has sudo permissions
if sudo -n true 2>/dev/null; then
    echo "This User has sudo permissions"
else
    echo "This User does not have sudo permissions"
    exit 1
fi

# Detect OS and set package/service managers
if [ -f /etc/redhat-release ]; then
    if grep -q "Rocky" /etc/redhat-release; then
        OS="Rocky"
        PACKAGE_MANAGER="dnf"
        SERVICE_MANAGER="systemctl"
    elif grep -q "AlmaLinux" /etc/redhat-release; then
        OS="AlmaLinux"
        PACKAGE_MANAGER="dnf"
        SERVICE_MANAGER="systemctl"
    else
        OS="CentOS"
        PACKAGE_MANAGER="yum"
        SERVICE_MANAGER="systemctl"
    fi
elif [ -f /etc/os-release ]; then
    . /etc/os-release
    case "$ID" in
        ubuntu)
            OS="Ubuntu"
            PACKAGE_MANAGER="apt"
            SERVICE_MANAGER="systemctl"
            ;;
        debian)
            OS="Debian"
            PACKAGE_MANAGER="apt"
            SERVICE_MANAGER="systemctl"
            ;;
        fedora)
            OS="Fedora"
            PACKAGE_MANAGER="dnf"
            SERVICE_MANAGER="systemctl"
            ;;
        *)
            echo "Unsupported OS"
            exit 1
            ;;
    esac
else
    echo "Unsupported OS"
    exit 1
fi

# Update
if [ "$PACKAGE_MANAGER" = "apt" ]; then
    sudo apt update
else
    sudo $PACKAGE_MANAGER update -y
fi

# Install necessary packages
install_package() {
    package=$1
    if ! command -v $package &> /dev/null; then
        echo "Installing $package..."
        sudo $PACKAGE_MANAGER install $package -y
    fi
}

install_package dialog
install_package whiptail
install_package jq
install_package lsof
install_package tar 
install_package wget
install_package git

if ! grep -q "alias portshift='bash <(curl https://raw.githubusercontent.com/ReturnFI/Port-Shifter/main/install.sh)'" ~/.bashrc; then
    echo "alias portshift='bash <(curl https://raw.githubusercontent.com/ReturnFI/Port-Shifter/main/install.sh)'" >> ~/.bashrc
    source ~/.bashrc
fi
clear


##########################
## Functions for GOST setup
install_gost() {
    if systemctl is-active --quiet gost; then
        if ! (whiptail --title "Confirm Installation" --yesno "GOST service is already installed. Do you want to reinstall?" 8 60); then
            whiptail --title "Installation Cancelled" --msgbox "Installation cancelled. GOST service remains installed." 8 60
            return
        fi
    fi

    {
        echo "10"
        curl -fsSL https://github.com/go-gost/gost/raw/master/install.sh | bash -s -- --install > /dev/null 2>&1
        echo "50"
        sudo wget -q -O /usr/lib/systemd/system/gost.service https://raw.githubusercontent.com/ReturnFI/Port-Shifter/main/gost.service > /dev/null 2>&1
        sleep 1
        echo "70"
    } | dialog --title "GOST Installation" --gauge "Installing GOST..." 10 60

    domain=$(whiptail --inputbox "Enter your domain or IP:" 8 60 --title "GOST Installation" 3>&1 1>&2 2>&3)
    while : ; do
        port=$(whiptail --inputbox "Enter the port number (1-65535):" 8 60 --title "Port Input" 3>&1 1>&2 2>&3)
        if [[ "$port" =~ ^[0-9]+$ && "$port" -ge 1 && "$port" -le 65535 ]]; then
            break
        else
            whiptail --title "Invalid Input" --msgbox "Port must be a numeric value between 1 and 65535. Please try again." 8 60
        fi
    done

    {
        echo "80"
        sudo sed -i "s|ExecStart=/usr/local/bin/gost -L=tcp://:\$port/\$domain:\$port|ExecStart=/usr/local/bin/gost -L=tcp://:$port/$domain:$port|g" /usr/lib/systemd/system/gost.service > /dev/null 2>&1
        sudo systemctl daemon-reload > /dev/null 2>&1
        sudo systemctl start gost > /dev/null 2>&1
        sudo systemctl enable gost > /dev/null 2>&1
        echo "100"
        sleep 1
    } | dialog --title "GOST Configuration" --gauge "Configuring GOST service..." 10 60

    status=$(sudo systemctl is-active gost)

    if [ "$status" = "active" ]; then
        whiptail --title "GOST Service Status" --msgbox "GOST tunnel is installed and active." 8 60
    else
        whiptail --title "GOST Installation" --msgbox "GOST service is not active. Status: $status." 8 60
    fi
    clear
}

check_port_gost() {
    gost_ports=$(sudo lsof -i -P -n -sTCP:LISTEN | grep gost | awk '{print $9}')
    status=$(sudo systemctl is-active gost)
    service_status="gost Service Status: $status"
    info="Service Status and Ports in Use:\n\nPorts in use:\n$gost_ports\n\n$service_status"
    whiptail --title "gost Service Status and Ports" --msgbox "$info" 15 70
}

add_port_gost() {
    if ! systemctl is-active --quiet gost; then
        whiptail --title "GOST Not Active" --msgbox "GOST service is not active.\nPlease start GOST before adding new configuration." 8 60
        return
    fi

    last_port=$(sudo lsof -i -P -n -sTCP:LISTEN | grep gost | awk '{print $9}' | awk -F ':' '{print $NF}' | sort -n | tail -n 1)

    new_domain=$(whiptail --inputbox "Enter your domain or IP:" 8 60  --title "GOST Installation" 3>&1 1>&2 2>&3)
    exit_status=$?
    if [ $exit_status != 0 ]; then
        whiptail --title "Cancelled" --msgbox "Operation cancelled. Returning to menu." 8 60
        return
    fi

    while : ; do
        new_port=$(whiptail --inputbox "Enter the port (numeric only):" 8 60 --title "Port Input" 3>&1 1>&2 2>&3)
        exit_status=$?
        if [ $exit_status != 0 ]; then
            whiptail --title "Cancelled" --msgbox "Operation cancelled. Returning to menu." 8 60
            return
        fi
        
        if [[ "$new_port" =~ ^[0-9]+$ ]]; then
            if (( new_port >= 0 && new_port <= 65535 )); then
                if sudo lsof -i -P -n -sTCP:LISTEN | grep ":$new_port " > /dev/null 2>&1; then
                    whiptail --title "Port Already in Use" --msgbox "Port $new_port is already in use. Please choose another port." 8 60
                else
                    break
                fi
            else
                whiptail --title "Invalid Port Number" --msgbox "Port number must be between 1 and 65535. Please try again." 8 60
            fi
        else
            whiptail --title "Invalid Input" --msgbox "Port must be a numeric value. Please try again." 8 60
        fi
    done

    sudo sed -i "/ExecStart/s/$/ -L=tcp:\/\/:$new_port\/$new_domain:$new_port/" /usr/lib/systemd/system/gost.service > /dev/null 2>&1
    sudo systemctl daemon-reload > /dev/null 2>&1
    sudo systemctl restart gost > /dev/null 2>&1
    whiptail --title "GOST configuration" --msgbox "New domain and port added." 8 60
}

remove_port_gost() {
    ports=$(grep -oP '(?<=-L=tcp://:)\d+(?=/)' /usr/lib/systemd/system/gost.service)

    if [ -z "$ports" ]; then
        whiptail --title "Remove Port" --msgbox "No ports found in the GOST configuration." 8 60
        return
    fi

    port_list=()
    for port in $ports; do
        port_list+=("$port" "")
    done

    selected_port=$(whiptail --title "Remove Port" --menu "Choose the port to remove:" 15 60 5 "${port_list[@]}" 3>&1 1>&2 2>&3)

    if [ -z "$selected_port" ]; then
        whiptail --title "Remove Port" --msgbox "No port selected. No changes made." 8 60
        return
    fi

    line=$(grep -oP "ExecStart=.*-L=tcp://:$selected_port/[^ ]+" /usr/lib/systemd/system/gost.service)
    domain=$(echo "$line" | grep -oP "(?<=-L=tcp://:$selected_port/).+")

    if whiptail --title "Confirm Removal" --yesno "Are you sure you want to remove the port $selected_port with domain/IP $domain?" 8 60; then
        sudo sed -i "\|ExecStart=.*-L=tcp://:$selected_port/$domain|s| -L=tcp://:$selected_port/$domain||" /usr/lib/systemd/system/gost.service

        {
            echo "50"
            sudo systemctl daemon-reload > /dev/null 2>&1
            sudo systemctl restart gost > /dev/null 2>&1
            echo "100"
        } | dialog --title "GOST Configuration" --gauge "Removing port $selected_port from GOST service..." 10 60

        whiptail --title "Remove Port" --msgbox "Port $selected_port with domain/IP $domain has been removed from the GOST configuration." 8 60
    else
        whiptail --title "Remove Port" --msgbox "No changes made." 8 60
    fi
}

uninstall_gost() {
    if whiptail --title "Confirm Uninstallation" --yesno "Are you sure you want to uninstall GOST?" 8 60; then
        {
            echo "20" "Stopping GOST service..."
            sudo systemctl stop gost > /dev/null 2>&1
            sleep 1
            echo "40" "Disabling GOST service..."
            sudo systemctl disable gost > /dev/null 2>&1
            sleep 1
            echo "60" "Reloading systemctl daemon..."
            sudo systemctl daemon-reload > /dev/null 2>&1
            sleep 1
            echo "80" "Removing GOST service and binary..."
            sudo rm -f /usr/lib/systemd/system/gost.service /usr/local/bin/gost
            sleep 1
        } | dialog --title "GOST Uninstallation" --gauge "Uninstalling GOST..." 10 60 0
        clear
        whiptail --title "GOST Uninstallation" --msgbox "GOST Service Uninstalled." 8 60
    else
        whiptail --title "GOST Uninstallation" --msgbox "Uninstallation cancelled." 8 60
    fi
}

##########################
## Functions for Xray setup
install_xray() {
    if systemctl is-active --quiet xray; then
        if ! (whiptail --title "Confirm Installation" --yesno "Xray service is already active. Do you want to reinstall?" 8 60); then
            whiptail --title "Installation Cancelled" --msgbox "Installation cancelled. Xray service remains active." 8 60
            return
        fi
    fi

    bash -c "$(curl -sL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install 2>&1 | dialog --title "Xray Installation" --progressbox 30 120

    whiptail --title "Xray Installation" --msgbox "Xray installation completed!" 8 60

    address=$(whiptail --inputbox "Enter your domain or IP:" 8 60 --title "Address Input" 3>&1 1>&2 2>&3)
    while : ; do
        port=$(whiptail --inputbox "Enter the port (numeric only 1-65535):" 8 60 --title "Port Input" 3>&1 1>&2 2>&3)
        if [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; then
            break
        else
            whiptail --title "Invalid Input" --msgbox "Port must be a numeric value between 1 and 65535. Please try again." 8 60
        fi
    done

    wget -q -O /tmp/config.json https://raw.githubusercontent.com/ReturnFI/Port-Shifter/main/config.json

    jq --arg address "$address" --arg port "$port" '.inbounds[1].port = ($port | tonumber) | .inbounds[1].settings.address = $address | .inbounds[1].settings.port = ($port | tonumber) | .inbounds[1].tag = "inbound-" + $port' /tmp/config.json > /usr/local/etc/xray/config.json
    clear
    sudo systemctl restart xray
    status=$(sudo systemctl is-active xray)

    if [ "$status" = "active" ]; then
        whiptail --title "Install Xray" --msgbox "Xray installed successfully!" 8 60
    else
        whiptail --title "Install Xray" --msgbox "Xray service is not active or failed." 8 60
    fi

    rm /tmp/config.json
}

check_service_xray() {
    xray_ports=$(sudo lsof -i -P -n -sTCP:LISTEN | grep xray | awk '{print $9}')

    status=$(sudo systemctl is-active xray)
    service_status="Xray Service Status: $status"

    info="Service Status and Ports in Use:\n\nPorts in use:\n$xray_ports\n\n$service_status"

    whiptail --title "Xray Service Status and Ports" --msgbox "$info" 15 70

}

trafficstat() {
    if ! systemctl is-active --quiet xray; then
    whiptail --title "Install Xray" --msgbox "xray service is not active.\nPlease start xray before check traffic." 8 60
        return
    fi
    
    local RESET=$1
    local APISERVER="127.0.0.1:10085"
    local XRAY="/usr/local/bin/xray"
    local ARGS=""
    
    if [[ "$RESET" == "reset" ]]; then
        ARGS="reset: true"
    fi

    local DATA=$($XRAY api statsquery --server="$APISERVER" "$ARGS" | awk '
    {
        if (match($1, /"name":/)) {
            f=1; gsub(/^"|link"|,$/, "", $2);
            split($2, p,  ">>>");
            printf "%s:%s->%s\t", p[1], p[2], p[4];
        } else if (match($1, /"value":/) && f) {
            f=0;
            gsub(/"/, "", $2);
            printf "%.0f\n\n", $2;
        } else if (match($0, /}/) && f) {
            f=0; 
            print 0;
        }
    }')

    local PREFIX="inbound"
    local SORTED=$(echo "$DATA" | grep "^${PREFIX}" | grep -v "inbound:api" | sort -r)
    local TOTAL_UP=0
    local TOTAL_DOWN=0

    while IFS= read -r LINE; do
        if [[ "$LINE" == *"->up"* ]]; then
            SIZE=$(echo "$LINE" | awk '{print $2}')
            TOTAL_UP=$((TOTAL_UP + SIZE))
        elif [[ "$LINE" == *"->down"* ]]; then
            SIZE=$(echo "$LINE" | awk '{print $2}')
            TOTAL_DOWN=$((TOTAL_DOWN + SIZE))
        fi
    done <<< "$SORTED"

    local OUTPUT=$(echo -e "${SORTED}\n" | numfmt --field=2 --suffix=B --to=iec | column -t)
    local TOTAL_UP_FMT=$(numfmt --to=iec <<< $TOTAL_UP)
    local TOTAL_DOWN_FMT=$(numfmt --to=iec <<< $TOTAL_DOWN)

    whiptail --msgbox "Inbound Traffic Statistics:\n\n${OUTPUT}\nTotal Up: ${TOTAL_UP_FMT}\nTotal Down: ${TOTAL_DOWN_FMT}" 20 80
}

add_another_inbound() {
    if ! systemctl is-active --quiet xray; then
    whiptail --title "Install Xray" --msgbox "xray service is not active.\nPlease start xray before adding new configuration." 8 60
        return
    fi
    addressnew=$(whiptail --inputbox "Enter the new address:" 8 60 --title "Address Input" 3>&1 1>&2 2>&3)
    exit_status=$?
    if [ $exit_status != 0 ]; then
        whiptail --title "Cancelled" --msgbox "Operation cancelled. Returning to menu." 8 60
        return
    fi

    while : ; do
        portnew=$(whiptail --inputbox "Enter the new port (numeric only):" 8 60 --title "Port Input" 3>&1 1>&2 2>&3)
        exit_status=$?
        if [ $exit_status != 0 ]; then
            whiptail --title "Cancelled" --msgbox "Operation cancelled. Returning to menu." 8 60
            return
        fi
        
        if ! [[ "$portnew" =~ ^[0-9]+$ ]] || ! (( portnew >= 1 && portnew <= 65535 )); then
            whiptail --title "Invalid Input" --msgbox "Port must be a numeric value between 1 and 65535. Please try again." 8 60
            continue
        fi

        if jq --arg port "$portnew" '.inbounds[] | select(.port == ($port | tonumber))' /usr/local/etc/xray/config.json | grep -q .; then
            whiptail --title "Port In Use" --msgbox "The port $portnew is already in use. Please enter a different port." 8 60
        else
            break
        fi
    done

    if jq --arg address "$addressnew" --arg port "$portnew" '.inbounds += [{ "listen": null, "port": ($port | tonumber), "protocol": "dokodemo-door", "settings": { "address": $address, "followRedirect": false, "network": "tcp,udp", "port": ($port | tonumber) }, "tag": ("inbound-" + $port) }]' /usr/local/etc/xray/config.json > /tmp/config.json.tmp; then
        sudo mv /tmp/config.json.tmp /usr/local/etc/xray/config.json
        sudo systemctl restart xray
        whiptail --title "Install Xray" --msgbox "Additional inbound added." 8 60
    else
        whiptail --title "Install Xray" --msgbox "Error: Failed to add inbound configuration." 8 60
    fi
}

remove_inbound() {
    inbounds=$(jq -r '.inbounds[] | select(.tag != "api") | "\(.tag):\(.port)"' /usr/local/etc/xray/config.json)
    
    if [ -z "$inbounds" ]; then
        whiptail --title "Remove Inbound" --msgbox "No inbound configurations found." 8 60
        return
    fi
    
    selected=$(whiptail --title "Remove Inbound" --menu "Select the inbound configuration to remove:" 20 60 10 \
    $(echo "$inbounds" | awk -F ':' '{print $1}' | nl -w2 -s ' ') 3>&1 1>&2 2>&3)

    if [ -n "$selected" ]; then
        port=$(echo "$inbounds" | sed -n "${selected}p" | awk -F ':' '{print $2}')
        
        # Confirm removal
        whiptail --title "Confirm Removal" --yesno "Are you sure you want to remove the inbound configuration for port $port?" 8 60
        response=$?
        if [ $response -eq 0 ]; then
            remove_inbound_by_port "$port"
        else
            whiptail --title "Remove Inbound" --msgbox "Inbound configuration removal canceled." 8 60
        fi
    fi
}

remove_inbound_by_port() {
    port=$1
    if jq --arg port "$port" 'del(.inbounds[] | select(.port == ($port | tonumber)))' /usr/local/etc/xray/config.json > /tmp/config.json.tmp; then
        sudo mv /tmp/config.json.tmp /usr/local/etc/xray/config.json
        sudo systemctl restart xray
        if grep -q "\"port\": $port" /usr/local/etc/xray/config.json; then
            whiptail --title "Remove Inbound" --msgbox "Failed to remove inbound configuration." 8 60
        else
            whiptail --title "Remove Inbound" --msgbox "Inbound configuration removed successfully!" 8 60
        fi
    else
        whiptail --title "Remove Inbound" --msgbox "Failed to remove inbound configuration." 8 60
    fi
}

uninstall_xray() {
    if whiptail --title "Confirm Uninstallation" --yesno "Are you sure you want to uninstall Xray?" 8 60; then
        (
        echo "10" "Removing Xray configuration..."
        sudo rm /usr/local/etc/xray/config.json > /dev/null 2>&1
        sleep 1
        echo "30" "Stopping and disabling Xray service..."
        sudo systemctl stop xray && sudo systemctl disable xray > /dev/null 2>&1
        sleep 1
        echo "70" "Uninstalling Xray..."
        sudo bash -c "$(curl -sL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove > /dev/null 2>&1
        sleep 1
        echo "100" "Xray Uninstallation completed!"
        sleep 1
        ) | dialog --title "Xray Uninstallation" --gauge "Xray Uninstallation in progress..." 10 100 0
        whiptail --title "Xray Uninstallation" --msgbox "Xray Uninstallation completed!" 8 60
        clear
    else
        whiptail --title "Xray Uninstallation" --msgbox "Uninstallation cancelled." 8 60
        clear
    fi
}

##############################
## Functions for HA-Proxy setup
install_haproxy() {
    if systemctl is-active --quiet haproxy; then
        if ! (whiptail --title "Confirm Installation" --yesno "HAProxy service is already active. Do you want to reinstall?" 8 60); then
            whiptail --title "Installation Cancelled" --msgbox "Installation cancelled. HAProxy service remains active." 8 60
            return
        fi
    fi

    {
        echo "10" "Installing HAProxy..."
        sudo $PACKAGE_MANAGER install haproxy -y > /dev/null 2>&1
        sleep 1
        echo "30" "Downloading haproxy.cfg..."
        wget -q -O /tmp/haproxy.cfg "https://raw.githubusercontent.com/ReturnFI/Port-Shifter/main/haproxy.cfg" > /dev/null 2>&1
        sleep 1
        echo "50" "Removing existing haproxy.cfg..."
        sudo rm /etc/haproxy/haproxy.cfg > /dev/null 2>&1
        sleep 1
        echo "70" "Moving new haproxy.cfg to /etc/haproxy..."
        sudo mv /tmp/haproxy.cfg /etc/haproxy/haproxy.cfg
        sleep 1
    } | dialog --title "HAProxy Installation" --gauge "Installing HAProxy..." 10 60 0

    whiptail --title "HAProxy Installation" --msgbox "HAProxy installation completed." 8 60

    while true; do
        target_iport=$(whiptail --inputbox "Enter Relay-Server Free Port (1-65535):" 8 60 --title "HAProxy Installation" 3>&1 1>&2 2>&3)
        if [[ "$target_iport" =~ ^[0-9]+$ ]] && [ "$target_iport" -ge 1 ] && [ "$target_iport" -le 65535 ]; then
            break
        else
            whiptail --title "Invalid Input" --msgbox "Please enter a valid numeric port between 1 and 65535." 8 60
        fi
    done

    target_ip=$(whiptail --inputbox "Enter Main-Server IP or Domain:" 8 60 --title "HAProxy Installation" 3>&1 1>&2 2>&3)

    while true; do
        target_port=$(whiptail --inputbox "Enter Main-Server Port (1-65535):" 8 60 --title "HAProxy Installation" 3>&1 1>&2 2>&3)
        if [[ "$target_port" =~ ^[0-9]+$ ]] && [ "$target_port" -ge 1 ] && [ "$target_port" -le 65535 ]; then
            break
        else
            whiptail --title "Invalid Input" --msgbox "Please enter a valid numeric port between 1 and 65535." 8 60
        fi
    done

    if [[ -n "$target_ip" ]]; then
        sudo sed -i "s/\$iport/$target_iport/g; s/\$IP/$target_ip/g; s/\$port/$target_port/g" /etc/haproxy/haproxy.cfg > /dev/null 2>&1
        sudo systemctl restart haproxy > /dev/null 2>&1

        status=$(sudo systemctl is-active haproxy)
        if [ "$status" = "active" ]; then
            whiptail --title "HAProxy Installation" --msgbox "HAProxy tunnel is installed and active." 8 60
        else
            whiptail --title "HAProxy Installation" --msgbox "HAProxy service is not active. Status: $status." 8 60
        fi
    else
        whiptail --title "HAProxy Installation" --msgbox "Invalid IP input. Please ensure the field is filled correctly." 8 60
    fi
}

check_haproxy() {
    haproxy_ports=$(sudo lsof -i -P -n -sTCP:LISTEN | grep haproxy | awk '{print $9}')
    status=$(sudo systemctl is-active haproxy)
    service_status="haproxy Service Status: $status"
    info="Service Status and Ports in Use:\n\nPorts in use:\n$haproxy_ports\n\n$service_status"
    whiptail --title "haproxy Service Status and Ports" --msgbox "$info" 15 70
}

add_frontend_backend() {

    if ! systemctl is-active --quiet haproxy; then
        whiptail --title "HAProxy Not Active" --msgbox "HAProxy service is not active.\nPlease start HAProxy before adding new configuration." 8 60
        return
    fi

    while true; do
        frontend_port=$(whiptail --inputbox "Enter Relay-Server Free Port (1-65535):" 8 60 --title "HAProxy Installation" 3>&1 1>&2 2>&3)
        exit_status=$?
        if [ $exit_status != 0 ]; then
            whiptail --title "Cancelled" --msgbox "Operation cancelled. Returning to menu." 8 60
            return
        fi
        
        if [[ "$frontend_port" =~ ^[0-9]+$ ]] && [ "$frontend_port" -ge 1 ] && [ "$frontend_port" -le 65535 ]; then
            if grep -q "frontend tunnel-$frontend_port" /etc/haproxy/haproxy.cfg; then
                whiptail --title "Port Already Used" --msgbox "Port $frontend_port is already in use. Please choose another port." 8 60
            else
                break
            fi
        else
            whiptail --title "Invalid Input" --msgbox "Please enter a valid numeric port between 1 and 65535." 8 60
        fi
    done

    backend_ip=$(whiptail --inputbox "Enter Main-Server IP or Domain:" 8 60 --title "Add Frontend/Backend" 3>&1 1>&2 2>&3)
    exit_status=$?
    if [ $exit_status != 0 ]; then
        whiptail --title "Cancelled" --msgbox "Operation cancelled. Returning to menu." 8 60
        return
    fi

    while true; do
        backend_port=$(whiptail --inputbox "Enter Main-Server Port (1-65535):" 8 60 --title "HAProxy Installation" 3>&1 1>&2 2>&3)
        exit_status=$?
        if [ $exit_status != 0 ]; then
            whiptail --title "Cancelled" --msgbox "Operation cancelled. Returning to menu." 8 60
            return
        fi
        
        if [[ "$backend_port" =~ ^[0-9]+$ ]] && [ "$backend_port" -ge 1 ] && [ "$backend_port" -le 65535 ]; then
            break
        else
            whiptail --title "Invalid Input" --msgbox "Please enter a valid numeric port between 1 and 65535." 8 60
        fi
    done

    {
        echo ""
        echo "frontend tunnel-$frontend_port"
        echo "    bind :::$frontend_port"
        echo "    mode tcp"
        echo "    default_backend tunnel-$backend_port"
        echo ""
        echo "backend tunnel-$backend_port"
        echo "    mode tcp"
        echo "    server target_server $backend_ip:$backend_port"
    } | sudo tee -a /etc/haproxy/haproxy.cfg > /dev/null

    sudo systemctl restart haproxy > /dev/null 2>&1

    whiptail --title "Frontend/Backend Added" --msgbox "New frontend and backend added successfully.\n\nFrontend: tunnel-$frontend_port\nBackend: tunnel-$backend_port" 10 60
}

remove_frontend_backend() {
    
    frontends=$(grep -E '^frontend ' /etc/haproxy/haproxy.cfg | awk '{print $2}')
    
    
    options=""
    for frontend in $frontends; do
        default_backend=$(grep -E "^frontend $frontend$" /etc/haproxy/haproxy.cfg -A 10 | grep 'default_backend' | awk '{print $2}')
        options+="$frontend \"$default_backend\" "
    done

    
    selected=$(whiptail --menu "Select Frontend to Remove" 20 60 10 $options 3>&1 1>&2 2>&3)

    if [[ -n "$selected" ]]; then
        frontend_name=$selected
        backend_name=$(grep -E "^frontend $frontend_name$" /etc/haproxy/haproxy.cfg -A 10 | grep 'default_backend' | awk '{print $2}')

        
        if [[ -n "$backend_name" ]]; then
            
            sudo sed -i "/^frontend $frontend_name$/,/^$/d" /etc/haproxy/haproxy.cfg

            
            sudo sed -i "/^backend $backend_name$/,/^$/d" /etc/haproxy/haproxy.cfg

            
            sudo systemctl restart haproxy > /dev/null 2>&1

            
            whiptail --title "Frontend/Backend Removed" --msgbox "Frontend '$frontend_name' and Backend '$backend_name' removed successfully." 8 60
        else
            
            whiptail --title "Error" --msgbox "Could not find the default backend for frontend '$frontend_name'." 8 60
        fi
    else
        
        whiptail --title "Cancelled" --msgbox "No frontend selected. Operation cancelled." 8 60
    fi
}

uninstall_haproxy() {
    if (whiptail --title "Confirm Uninstallation" --yesno "Are you sure you want to uninstall HAProxy?" 8 60); then
        {
            echo "20" "Stopping HAProxy service..."
            sudo systemctl stop haproxy > /dev/null 2>&1
            sleep 1
            echo "40" "Disabling HAProxy service..."
            sudo systemctl disable haproxy > /dev/null 2>&1
            sleep 1
            echo "60" "Removing HAProxy..."
            sudo $PACKAGE_MANAGER remove haproxy -y > /dev/null 2>&1
            sleep 1
        } | dialog --title "HAProxy Uninstallation" --gauge "Uninstalling HAProxy..." 10 60 0

        whiptail --title "HAProxy Uninstallation" --msgbox "HAProxy Uninstalled." 8 60
        clear
    else
        whiptail --title "HAProxy Uninstallation" --msgbox "Uninstallation cancelled." 8 60
        clear
    fi
}

##############################
## Functions for Options setup
configure_dns() {

    sudo cp /etc/resolv.conf /etc/resolv.conf.backup
    sudo rm /etc/resolv.conf > /dev/null 2>&1

    dns1=$(whiptail --inputbox "Enter DNS Server 1 (like 8.8.8.8):" 8 60 3>&1 1>&2 2>&3)
    exitstatus=$?
    
    if [ $exitstatus != 0 ] || [ -z "$dns1" ]; then
        whiptail --title "DNS Configuration" --msgbox "Operation cancelled or invalid input. Restoring default DNS configuration." 8 60
        restore_dns
        exit 1
    fi

    dns2=$(whiptail --inputbox "Enter DNS Server 2 (like 8.8.4.4):" 8 60 3>&1 1>&2 2>&3)
    exitstatus=$?
    
    if [ $exitstatus != 0 ] || [ -z "$dns2" ]; then
        whiptail --title "DNS Configuration" --msgbox "Operation cancelled or invalid input. Restoring default DNS configuration." 8 60
        restore_dns
        exit 1
    fi

    echo "nameserver $dns1" | sudo tee -a /etc/resolv.conf > /dev/null
    echo "nameserver $dns2" | sudo tee -a /etc/resolv.conf > /dev/null

    whiptail --title "DNS Configuration" --msgbox "DNS Configuration completed." 8 60
    clear
}

restore_dns() {
    echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf > /dev/null
    echo "nameserver 1.1.1.1" | sudo tee -a /etc/resolv.conf > /dev/null
}

function update_server() {
    (
        sudo $PACKAGE_MANAGER update -y
        echo "100" "Update completed."
    ) | dialog --title "Update Server" --progressbox 30 120

    whiptail --title "Update Server" --msgbox "Server Update completed." 8 60
    clear
}

function ping_websites() {
    websites=("github.com" "google.com" "www.cloudflare.com")
    results_file=$(mktemp)

    for website in "${websites[@]}"; do
        gauge_title="Pinging $website"
        gauge_percentage=0
        success=false

        (
            for _ in {1..5}; do
                sleep 1  
                ((gauge_percentage += 20))
                echo "$gauge_percentage"
                echo "# $gauge_title"
                echo "Pinging $website..."
                
                if ping -c 1 $website &> /dev/null; then
                    success=true
                fi
            done
            echo "100" 
        ) | dialog --title "Ping $website" --gauge "$gauge_title" 10 80 0

        result=$(ping -c 5 $website | tail -n 2)
        echo -e "\n\nPing results for $website:\n$result" >> "$results_file"
    done

    whiptail --title "Ping Websites" --textbox "$results_file" 30 80
    clear

    rm "$results_file"
}


################################################################
# Define the functions to be executed when an option is selected

# Graphical functionality for IP-Tables menu
iptables_menu() {
    while true; do
        choice=$(whiptail --backtitle "Port-Shifter" --title "IP-Tables Menu" --menu "Please choose one of the following options:" 20 60 10 \
        "Install" "Install IP-Tables Rules" \
        "Status" "Check Ports In Use" \
        "Uninstall" "Uninstall IP-Tables Rules" \
        "Back" "Back To Main Menu" 3>&1 1>&2 2>&3)

        # Check the return value of the whiptail command
        if [ $? -eq 0 ]; then
            # Check if the user selected a valid option
            case $choice in
                Install)
                    install_iptables
                    ;;
                Status)
                    check_port_iptables
                    ;;
                Uninstall)
                    uninstall_iptables
                    ;;
                Back)
                    menu
                    ;;
                *)
                    whiptail --title "Invalid Option" --msgbox "Please select a valid option." 8 60
                    exit 1
                    ;;
            esac
        else
            exit 1
        fi
    done
}

# Graphical functionality for GOST menu
gost_menu() {
    while true; do
        choice=$(whiptail --backtitle "Port-Shifter" --title "GOST Menu" --menu "Please choose one of the following options:" 20 60 10 \
        "Install" "Install GOST" \
        "Status" "Check GOST Port And Status" \
        "Add" "Add Another Port And Domain" \
        "Remove" "Remove Port And Domain" \
        "Uninstall" "Uninstall GOST" \
        "Back" "Back To Main Menu" 3>&1 1>&2 2>&3)

        # Check the return value of the whiptail command
        if [ $? -eq 0 ]; then
            # Check if the user selected a valid option
            case $choice in
                Install)
                    install_gost
                    ;;
                Status)
                    check_port_gost
                    ;;
                Add)
                    add_port_gost
                    ;;
                Remove)
                    remove_port_gost
                    ;;
                Uninstall)
                    uninstall_gost
                    ;;
                Back)
                    menu
                    ;;
                *)
                    whiptail --title "Invalid Option" --msgbox "Please select a valid option." 8 60
                    exit 1
                    ;;
            esac
        else
            exit 1
        fi
    done
}

# Graphical functionality for dokodemo menu
dokodemo_menu() {
    while true; do
        choice=$(whiptail --backtitle "Port-Shifter" --title "Dokodemo-Door Menu" --menu "Please choose one of the following options:" 20 60 10 \
        "Install" "Install Xray For Dokodemo-Door And Add Inbound" \
        "Status" "Check Xray Service Status" \
        "Traffic" "Inbound Traffic Statistics" \
        "Add" "Add Another Inbound" \
        "Remove" "Remove an Inbound Configuration" \
        "Uninstall" "Uninstall Xray And Tunnel" \
        "Back" "Back To Main Menu" 3>&1 1>&2 2>&3)

        # Check the return value of the whiptail command
        if [ $? -eq 0 ]; then
            # Check if the user selected a valid option
            case $choice in
                Install)
                    install_xray
                    ;;
                Status)
                    check_service_xray
                    ;;
                Traffic)
                    trafficstat
                     ;;
                Add)
                    add_another_inbound
                    ;;
                Remove)
                    remove_inbound
                    ;;
                Uninstall)
                    uninstall_xray
                    ;;
                Back)
                    menu
                    ;;
                *)
                    whiptail --title "Invalid Option" --msgbox "Please select a valid option." 8 60
                    exit 1
                    ;;
            esac
        else
            exit 1
        fi
    done
}

# Graphical functionality for Socat menu
haproxy_menu() {
    while true; do
        choice=$(whiptail --backtitle "Port-Shifter" --title "HA-Proxy Menu" --menu "Please choose one of the following options:" 20 60 10 \
        "Install" "Install HA-Proxy" \
        "Status" "Check HA-Proxy Port and Status" \
        "Add" "Add more tunnel Configuration" \
        "Remove" "Remove tunnel Configuration" \
        "Uninstall" "Uninstall HAProxy" \
        "Back" "Back To Main Menu" 3>&1 1>&2 2>&3)

        # Check the return value of the whiptail command
        if [ $? -eq 0 ]; then
            # Check if the user selected a valid option
            case $choice in
                Install)
                    install_haproxy
                    ;;
                Status)
                    check_haproxy
                    ;;
                Add)
                    add_frontend_backend
                    ;;
                Remove)
                    remove_frontend_backend
                    ;;
                Uninstall)
                    uninstall_haproxy
                    ;;
                Back)
                    menu
                    ;;
                *)
                    whiptail --title "Invalid Option" --msgbox "Please select a valid option." 8 60
                    exit 1
                    ;;
            esac
        else
            exit 1
        fi
    done
}

# Define the submenu for Other Options
function other_options_menu() {
    while true; do
        other_choice=$(whiptail --backtitle "Welcome to Port-Shifter" --title "Other Options" --menu "Please choose one of the following options:" 20 60 10 \
        "DNS" "Configure DNS" \
        "Update" "Update Server" \
        "Ping" "Ping to check internet connectivity" \
        "Back" "Return to Main Menu" 3>&1 1>&2 2>&3)

        # Check the return value of the whiptail command
        if [ $? -eq 0 ]; then
            # Check if the user selected a valid option
            case $other_choice in
                DNS)
                    configure_dns
                    ;;
                Update)
                    update_server
                    ;;
                Ping)
                    ping_websites
                    ;;
                Back)
                    menu
                    ;;
                *)
                    whiptail --title "Invalid Option" --msgbox "Please select a valid option." 8 60
                    ;;
            esac
        else
            exit 1
        fi
    done
}
#################################
# Define the main graphical menu
function menu() {
    while true; do
        choice=$(whiptail --backtitle "Welcome to Port-Shifter" --title "Choose Your Tunnel Mode" --menu "Please choose one of the following options:" 20 60 10 \
        "IP-Tables" "Manage IP-Tables Tunnel" \
        "GOST" "Manage GOST Tunnel" \
        "Dokodemo-Door" "Manage Dokodemo-Door Tunnel" \
        "HA-Proxy" "Manage HA-Proxy Tunnel" \
        "Options" "Additional Configuration Options" \
        "Quit" "Exit From The Script" 3>&1 1>&2 2>&3)

        # Check the return value of the whiptail command
        if [ $? -eq 0 ]; then
            # Check if the user selected a valid option
            case $choice in
                IP-Tables)
                    iptables_menu
                    ;;
                GOST)
                    gost_menu
                    ;;
                Dokodemo-Door)
                    dokodemo_menu
                    ;;
                HA-Proxy)
                    haproxy_menu
                    ;;
                Options)
                    other_options_menu
                    ;;
                Quit)
                    exit 0
                    ;;
                *)
                    whiptail --title "Invalid Option" --msgbox "Please select a valid option." 8 60
                    exit 1
                    ;;
            esac
        else
            exit 1
        fi
    done
}

# Call the menu function
menu
