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

install_gost() {
    clear
    if systemctl is-active --quiet gost; then
        if ! confirm_action "GOST seems to be installed. Do you want to reinstall?"; then
            show_message "info" "Installation cancelled."
            pause_for_key; return
        fi
    fi

    show_message "info" "Installing GOST from official script..."
    if ! curl -fsSL https://github.com/go-gost/gost/raw/master/install.sh | bash; then
        show_message "error" "GOST installation failed. Aborting."
        pause_for_key; return
    fi

    show_message "info" "Downloading GOST service file..."
    sudo wget -q -O /etc/systemd/system/gost.service "$repository_url"/config/gost.service

    prompt_for_input "Enter the Main-Server IP or Domain to forward to: " domain
    while true; do
        prompt_for_input "Enter the port number to listen on and forward (1-65535): " port
        if [[ "$port" =~ ^[0-9]+$ && "$port" -ge 1 && "$port" -le 65535 ]]; then
            break
        else
            show_message "error" "Invalid port. Please enter a number between 1-65535."
        fi
    done

    show_message "info" "Configuring GOST service..."
    sudo sed -i "s|ExecStart=.*|ExecStart=/usr/local/bin/gost -L=tcp://:$port/$domain:$port|" /etc/systemd/system/gost.service
    sudo systemctl daemon-reload
    sudo systemctl enable --now gost

    if systemctl is-active --quiet gost; then
        show_message "success" "GOST tunnel is installed and active."
    else
        show_message "error" "GOST service failed to start. Check logs with 'journalctl -u gost'."
    fi
    pause_for_key
}

check_port_gost() {
    clear
    show_message "info" "--- GOST Service Status ---"
    systemctl status gost --no-pager
    show_message "info" "---------------------------"
    gost_ports=$(sudo lsof -i -P -n -sTCP:LISTEN | grep gost | awk '{print $9}')
    if [ -n "$gost_ports" ]; then
        show_message "success" "GOST is listening on ports:\n$gost_ports"
    else
        show_message "warning" "GOST does not appear to be listening on any ports."
    fi
    pause_for_key
}

add_port_gost() {
    clear
    if ! systemctl is-active --quiet gost; then
        show_message "error" "GOST service is not active. Cannot add a new tunnel."
        pause_for_key; return
    fi

    prompt_for_input "Enter the new Main-Server IP or Domain: " new_domain
    while true; do
        prompt_for_input "Enter the new port (1-65535): " new_port
        if ! [[ "$new_port" =~ ^[0-9]+$ ]] || ! (( new_port >= 1 && new_port <= 65535 )); then
            show_message "error" "Invalid port. Must be a number between 1-65535."
        elif sudo lsof -i -P -n -sTCP:LISTEN | grep -q ":$new_port "; then
            show_message "error" "Port $new_port is already in use. Please choose another."
        else
            break
        fi
    done

    show_message "info" "Adding new tunnel to GOST service..."
    sudo sed -i "/ExecStart/s/$/ -L=tcp:\/\/:$new_port\/$new_domain:$new_port/" /etc/systemd/system/gost.service
    sudo systemctl daemon-reload
    sudo systemctl restart gost
    show_message "success" "New GOST tunnel added for port $new_port."
    pause_for_key
}

remove_port_gost() {
    clear
    show_message "info" "--- Remove GOST Tunnel ---"
    
    exec_line=$(grep "^ExecStart=" /etc/systemd/system/gost.service)
    mapfile -t tunnels < <(echo "$exec_line" | grep -oP '(-L=[^ ]+)')

    if [ ${#tunnels[@]} -eq 0 ]; then
        show_message "warning" "No tunnels found to remove."
        pause_for_key; return
    fi

    show_message "info" "Available tunnels to remove:"
    for i in "${!tunnels[@]}"; do
        echo " $((i+1)). ${tunnels[$i]}"
    done
    echo " c. Cancel"
    show_message "info" "-----------------------------"
    
    prompt_for_input "Enter the number of the tunnel to remove: " choice
    if [[ "$choice" =~ ^[Cc]$ ]]; then
        show_message "info" "Removal cancelled."; sleep 1; return
    fi

    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#tunnels[@]}" ]; then
        tunnel_to_remove=${tunnels[$((choice-1))]}
        
        if confirm_action "Remove tunnel '$tunnel_to_remove'?"; then
            sudo sed -i "s| $tunnel_to_remove||" /etc/systemd/system/gost.service
            sudo systemctl daemon-reload
            sudo systemctl restart gost
            show_message "success" "Tunnel removed."
        else
            show_message "info" "Removal cancelled."
        fi
    else
        show_message "error" "Invalid selection."
    fi
    pause_for_key
}

uninstall_gost() {
    clear
    if confirm_action "Are you sure you want to completely uninstall GOST?"; then
        show_message "info" "Stopping and disabling GOST service..."
        sudo systemctl stop gost >/dev/null 2>&1
        sudo systemctl disable gost >/dev/null 2>&1
        show_message "info" "Removing service file and GOST binary..."
        sudo rm -f /etc/systemd/system/gost.service /usr/local/bin/gost
        sudo systemctl daemon-reload
        show_message "success" "GOST has been uninstalled."
    else
        show_message "info" "Uninstallation cancelled."
    fi
    pause_for_key
}