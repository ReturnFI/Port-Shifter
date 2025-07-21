#!/bin/bash

source /opt/Port-Shifter/scripts/path.sh
source /opt/Port-Shifter/scripts/package.sh

prompt_for_input() {
    local prompt_message="$1"
    local variable_name="$2"
    echo -e -n "${YELLOW}$prompt_message ${NC}"
    read -r "$variable_name"
}

confirm_action() {
    local question="$1"
    while true; do
        read -r -p "$(echo -e "${YELLOW}$question (y/n): ${NC}")" choice
        case "$choice" in
            [Yy]*) return 0 ;;
            [Nn]*) return 1 ;;
            *) show_message "error" "Invalid input. Please enter 'y' or 'n'." ;;
        esac
    done
}

install_xray() {
    if systemctl is-active --quiet xray; then
        if ! confirm_action "Xray is already active. Do you want to reinstall?"; then
            show_message "info" "Installation cancelled."
            return
        fi
    fi

    show_message "info" "Installing Xray..."
    bash -c "$(curl -sL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
    show_message "success" "Xray core installed."

    prompt_for_input "Enter your domain or IP: " address
    while true; do
        prompt_for_input "Enter the port (1-65535): " port
        if [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; then
            break
        else
            show_message "error" "Invalid port. Please enter a numeric value between 1 and 65535."
        fi
    done

    show_message "info" "Downloading and configuring Xray..."
    wget -q -O /tmp/config.json "$repository_url"/config/config.json

    jq --arg address "$address" --argjson port "$port" \
       '.inbounds[1].port = $port | .inbounds[1].settings.address = $address | .inbounds[1].settings.port = $port | .inbounds[1].tag = "inbound-" + ($port | tostring)' \
       /tmp/config.json > /usr/local/etc/xray/config.json
    
    rm /tmp/config.json
    systemctl restart xray

    if systemctl is-active --quiet xray; then
        show_message "success" "Xray installed and started successfully on port $port."
    else
        show_message "error" "Xray service failed to start. Please check the logs with 'journalctl -u xray'."
    fi
    read -n 1 -s -r -p "Press any key to continue..."
}

check_service_xray() {
    clear
    show_message "info" "--- Xray Service Status ---"
    systemctl status xray --no-pager
    show_message "info" "---------------------------"
    xray_ports=$(lsof -i -P -n -sTCP:LISTEN | grep xray | awk '{print $9}')
    if [ -n "$xray_ports" ]; then
        show_message "success" "Xray is listening on ports:\n$xray_ports"
    else
        show_message "warning" "Xray does not appear to be listening on any ports."
    fi
    read -n 1 -s -r -p "Press any key to return to the menu..."
}

trafficstat() {
    if ! systemctl is-active --quiet xray; then
        show_message "error" "Xray service is not active. Cannot check traffic."
        read -n 1 -s -r -p "Press any key to continue..."
        return
    fi
    
    local APISERVER="127.0.0.1:10085"
    local XRAY_BIN="/usr/local/bin/xray"
    
    show_message "info" "Querying traffic statistics..."
    local DATA
    DATA=$($XRAY_BIN api statsquery --server="$APISERVER" | awk '
        /name/ {
            gsub(/"/, "", $2); gsub(/link"|,/, "", $2);
            split($2, p, ">>>");
            printf "%s:%s->%s\t", p[1], p[2], p[4];
        }
        /value/ {
            gsub(/"|,/, "", $2);
            printf "%.0f\n", $2;
        }')

    clear
    show_message "info" "--- Inbound Traffic Statistics ---"
    echo "$DATA" | grep "^inbound:" | grep -v "inbound:api" | numfmt --field=2 --suffix=B --to=iec | column -t
    show_message "info" "----------------------------------"
    read -n 1 -s -r -p "Press any key to return to the menu..."
}

add_another_inbound() {
    if ! systemctl is-active --quiet xray; then
        show_message "error" "Xray service is not active. Cannot add a new inbound."
        read -n 1 -s -r -p "Press any key to continue..."
        return
    fi

    prompt_for_input "Enter the new address/domain: " addressnew
    while true; do
        prompt_for_input "Enter the new port (1-65535): " portnew
        if ! [[ "$portnew" =~ ^[0-9]+$ ]] || ! (( portnew >= 1 && portnew <= 65535 )); then
            show_message "error" "Invalid port. Please enter a numeric value between 1 and 65535."
            continue
        fi
        if jq -e --argjson port "$portnew" '.inbounds[] | select(.port == $port)' /usr/local/etc/xray/config.json > /dev/null; then
            show_message "error" "Port $portnew is already in use. Please choose another."
        else
            break
        fi
    done

    show_message "info" "Adding new inbound configuration..."
    jq --arg address "$addressnew" --argjson port "$portnew" \
       '.inbounds += [{ "listen": null, "port": $port, "protocol": "dokodemo-door", "settings": { "address": $address, "followRedirect": false, "network": "tcp,udp", "port": $port }, "tag": ("inbound-" + ($port | tostring)) }]' \
       /usr/local/etc/xray/config.json > /tmp/config.json.tmp
    
    if mv /tmp/config.json.tmp /usr/local/etc/xray/config.json; then
        systemctl restart xray
        show_message "success" "New inbound for $addressnew on port $portnew added."
    else
        show_message "error" "Failed to update config file."
    fi
    read -n 1 -s -r -p "Press any key to continue..."
}

remove_inbound() {
    clear
    show_message "info" "--- Remove Inbound Configuration ---"
    
    local inbounds
    inbounds=$(jq -r '.inbounds[] | select(.tag != "api") | "\(.port) \(.settings.address) (\(.tag))"' /usr/local/etc/xray/config.json)

    if [ -z "$inbounds" ]; then
        show_message "warning" "No removable inbounds found."
        read -n 1 -s -r -p "Press any key to continue..."
        return
    fi

    show_message "info" "Available inbounds to remove:"
    mapfile -t options < <(echo "$inbounds")
    for i in "${!options[@]}"; do
        echo " $((i+1)). ${options[$i]}"
    done
    echo " c. Cancel"
    show_message "info" "--------------------------------------"

    prompt_for_input "Enter the number of the inbound to remove: " choice
    if [[ "$choice" =~ ^[Cc]$ ]]; then
        show_message "info" "Removal cancelled."
        sleep 1
        return
    fi

    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#options[@]}" ]; then
        local selected_inbound=${options[$((choice-1))]}
        local port_to_remove
        port_to_remove=$(echo "$selected_inbound" | awk '{print $1}')
        
        if confirm_action "Are you sure you want to remove the inbound on port $port_to_remove?"; then
            show_message "info" "Removing inbound on port $port_to_remove..."
            jq --argjson port "$port_to_remove" 'del(.inbounds[] | select(.port == $port))' /usr/local/etc/xray/config.json > /tmp/config.json.tmp
            mv /tmp/config.json.tmp /usr/local/etc/xray/config.json
            systemctl restart xray
            show_message "success" "Inbound removed successfully."
        else
            show_message "info" "Removal cancelled."
        fi
    else
        show_message "error" "Invalid selection."
    fi
    read -n 1 -s -r -p "Press any key to continue..."
}

uninstall_xray() {
    if confirm_action "Are you sure you want to completely uninstall Xray?"; then
        show_message "info" "Stopping and disabling Xray service..."
        systemctl stop xray >/dev/null 2>&1
        systemctl disable xray >/dev/null 2>&1
        
        show_message "info" "Running the official uninstaller..."
        bash -c "$(curl -sL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove --purge
        
        show_message "info" "Removing configuration files..."
        rm -f /usr/local/etc/xray/config.json
        
        show_message "success" "Xray has been completely uninstalled."
    else
        show_message "info" "Uninstallation cancelled."
    fi
    read -n 1 -s -r -p "Press any key to continue..."
}