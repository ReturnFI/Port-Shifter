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

pause_for_key() {
    read -n 1 -s -r -p "Press any key to continue..."
    echo
}

install_haproxy() {
    clear
    if systemctl is-active --quiet haproxy; then
        if ! confirm_action "HAProxy is already active. Do you want to reinstall?"; then
            show_message "info" "Installation cancelled."
            pause_for_key
            return
        fi
    fi

    show_message "info" "Installing HAProxy package..."
    if ! sudo $PACKAGE_MANAGER install haproxy -y > /dev/null 2>&1; then
        show_message "error" "Failed to install HAProxy. Aborting."
        pause_for_key
        return
    fi
    show_message "success" "HAProxy package installed."

    show_message "info" "Downloading and setting up haproxy.cfg..."
    wget -q -O /tmp/haproxy.cfg "$repository_url"/config/haproxy.cfg
    sudo mv /tmp/haproxy.cfg /etc/haproxy/haproxy.cfg
    show_message "success" "Configuration file placed."

    while true; do
        prompt_for_input "Enter this Relay-Server's port to listen on (1-65535): " target_iport
        if [[ "$target_iport" =~ ^[0-9]+$ ]] && [ "$target_iport" -ge 1 ] && [ "$target_iport" -le 65535 ]; then
            break
        else
            show_message "error" "Invalid port. Please enter a number between 1-65535."
        fi
    done

    prompt_for_input "Enter the Main-Server's IP or Domain to forward to: " target_ip

    while true; do
        prompt_for_input "Enter the Main-Server's Port to forward to (1-65535): " target_port
        if [[ "$target_port" =~ ^[0-9]+$ ]] && [ "$target_port" -ge 1 ] && [ "$target_port" -le 65535 ]; then
            break
        else
            show_message "error" "Invalid port. Please enter a number between 1-65535."
        fi
    done

    if [[ -n "$target_ip" ]]; then
        show_message "info" "Applying configuration..."
        sudo sed -i "s/\$iport/$target_iport/g; s/\$IP/$target_ip/g; s/\$port/$target_port/g" /etc/haproxy/haproxy.cfg
        sudo systemctl restart haproxy

        if systemctl is-active --quiet haproxy; then
            show_message "success" "HAProxy tunnel is installed and active."
        else
            show_message "error" "HAProxy service failed to start. Check logs with 'journalctl -u haproxy'."
        fi
    else
        show_message "error" "Main-Server IP cannot be empty. Installation aborted."
    fi
    pause_for_key
}

check_haproxy() {
    clear
    show_message "info" "--- HAProxy Service Status ---"
    systemctl status haproxy --no-pager
    show_message "info" "------------------------------"
    haproxy_ports=$(sudo lsof -i -P -n -sTCP:LISTEN | grep haproxy | awk '{print $9}')
    if [ -n "$haproxy_ports" ]; then
        show_message "success" "HAProxy is listening on ports:\n$haproxy_ports"
    else
        show_message "warning" "HAProxy does not appear to be listening on any ports."
    fi
    pause_for_key
}

add_frontend_backend() {
    clear
    if ! systemctl is-active --quiet haproxy; then
        show_message "error" "HAProxy service is not active. Cannot add configuration."
        pause_for_key
        return
    fi

    while true; do
        prompt_for_input "Enter a new free port for this Relay-Server (1-65535): " frontend_port
        if [[ "$frontend_port" =~ ^[0-9]+$ ]] && [ "$frontend_port" -ge 1 ] && [ "$frontend_port" -le 65535 ]; then
            if grep -q "bind .*:$frontend_port" /etc/haproxy/haproxy.cfg; then
                show_message "error" "Port $frontend_port is already in use. Please choose another."
            else
                break
            fi
        else
            show_message "error" "Invalid port. Please enter a number between 1-65535."
        fi
    done

    prompt_for_input "Enter the Main-Server IP or Domain for this tunnel: " backend_ip
    while true; do
        prompt_for_input "Enter the Main-Server Port for this tunnel (1-65535): " backend_port
        if [[ "$backend_port" =~ ^[0-9]+$ ]] && [ "$backend_port" -ge 1 ] && [ "$backend_port" -le 65535 ]; then
            break
        else
            show_message "error" "Invalid port. Please enter a number between 1-65535."
        fi
    done

    show_message "info" "Adding new frontend and backend to config..."
    {
        echo ""
        echo "frontend tunnel-$frontend_port"
        echo "    bind :$frontend_port"
        echo "    mode tcp"
        echo "    default_backend backend-$backend_ip-$backend_port"
        echo ""
        echo "backend backend-$backend_ip-$backend_port"
        echo "    mode tcp"
        echo "    server target_server $backend_ip:$backend_port"
    } | sudo tee -a /etc/haproxy/haproxy.cfg > /dev/null

    sudo systemctl restart haproxy
    show_message "success" "New tunnel configuration added."
    pause_for_key
}

remove_frontend_backend() {
    clear
    show_message "info" "--- Remove HAProxy Tunnel ---"
    
    mapfile -t frontends < <(grep -oP '(?<=^frontend )[^\s]+' /etc/haproxy/haproxy.cfg)
    if [ ${#frontends[@]} -eq 0 ]; then
        show_message "warning" "No tunnels found to remove."
        pause_for_key
        return
    fi

    show_message "info" "Available tunnels to remove:"
    for i in "${!frontends[@]}"; do
        echo " $((i+1)). ${frontends[$i]}"
    done
    echo " c. Cancel"
    show_message "info" "-----------------------------"

    prompt_for_input "Enter the number of the tunnel to remove: " choice
    if [[ "$choice" =~ ^[Cc]$ ]]; then
        show_message "info" "Removal cancelled."
        sleep 1; return
    fi

    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#frontends[@]}" ]; then
        frontend_name=${frontends[$((choice-1))]}
        backend_name=$(grep -A 5 "frontend $frontend_name" /etc/haproxy/haproxy.cfg | grep 'default_backend' | awk '{print $2}')
        
        if confirm_action "Remove tunnel '$frontend_name' -> '$backend_name'?"; then
            sudo sed -i "/^frontend $frontend_name$/,/^$/d" /etc/haproxy/haproxy.cfg
            sudo sed -i "/^backend $backend_name$/,/^$/d" /etc/haproxy/haproxy.cfg
            sudo systemctl restart haproxy
            show_message "success" "Tunnel removed successfully."
        else
            show_message "info" "Removal cancelled."
        fi
    else
        show_message "error" "Invalid selection."
    fi
    pause_for_key
}

uninstall_haproxy() {
    clear
    if confirm_action "Are you sure you want to completely uninstall HAProxy?"; then
        show_message "info" "Stopping and disabling HAProxy service..."
        sudo systemctl stop haproxy > /dev/null 2>&1
        sudo systemctl disable haproxy > /dev/null 2>&1
        show_message "info" "Removing HAProxy package and configuration..."
        sudo $PACKAGE_MANAGER remove haproxy -y > /dev/null 2>&1
        sudo rm -rf /etc/haproxy
        show_message "success" "HAProxy has been uninstalled."
    else
        show_message "info" "Uninstallation cancelled."
    fi
    pause_for_key
}