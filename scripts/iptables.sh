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

install_iptables() {
    clear
    show_message "info" "--- IPTables Tunnel Setup ---"

    prompt_for_input "Enter the Main-Server IP to forward traffic to (e.g., 1.1.1.1): " IP
    prompt_for_input "Enter ports to forward, separated by commas (e.g., 80,443): " PORTS

    if [ -z "$IP" ] || [ -z "$PORTS" ]; then
        show_message "error" "IP address and ports cannot be empty. Aborting."
        pause_for_key
        return
    fi
    
    show_message "info" "Installing iptables-persistent package..."
    if [ "$PACKAGE_MANAGER" = "apt" ]; then
        sudo $PACKAGE_MANAGER install iptables-persistent -y > /dev/null 2>&1
    else 
        sudo $PACKAGE_MANAGER install iptables-services -y > /dev/null 2>&1
    fi

    show_message "info" "Enabling IP forwarding..."
    sudo sysctl -w net.ipv4.ip_forward=1 > /dev/null 2>&1
    echo "net.ipv4.ip_forward=1" | sudo tee /etc/sysctl.d/99-port-shifter.conf > /dev/null

    show_message "info" "Configuring IPTables rules for ports: $PORTS..."
    sudo iptables -t nat -A PREROUTING -p tcp -m multiport --dports "$PORTS" -j DNAT --to-destination "$IP"
    sudo iptables -t nat -A PREROUTING -p udp -m multiport --dports "$PORTS" -j DNAT --to-destination "$IP"
    sudo iptables -t nat -A POSTROUTING -j MASQUERADE

    show_message "info" "Saving rules..."
    sudo mkdir -p /etc/iptables/
    sudo iptables-save | sudo tee /etc/iptables/rules.v4 > /dev/null

    show_message "success" "IPTables rules installed and saved successfully."
    pause_for_key
}

check_port_iptables() {
    clear
    show_message "info" "--- Current IPTables NAT Rules ---"
    sudo iptables -t nat -L PREROUTING -n -v
    echo ""
    sudo iptables -t nat -L POSTROUTING -n -v
    show_message "info" "----------------------------------"
    ip_forward_status=$(cat /proc/sys/net/ipv4/ip_forward)
    if [ "$ip_forward_status" -eq 1 ]; then
        show_message "success" "IP Forwarding is ENABLED."
    else
        show_message "warning" "IP Forwarding is DISABLED."
    fi
    pause_for_key
}

uninstall_iptables() {
    clear
    if confirm_action "Are you sure you want to flush all IPTables NAT rules?"; then
        show_message "info" "Flushing NAT table rules..."
        sudo iptables -t nat -F PREROUTING
        sudo iptables -t nat -F POSTROUTING
        
        show_message "info" "Disabling IP forwarding..."
        sudo sysctl -w net.ipv4.ip_forward=0 > /dev/null 2>&1
        sudo rm -f /etc/sysctl.d/99-port-shifter.conf

        show_message "info" "Saving empty ruleset..."
        sudo iptables-save | sudo tee /etc/iptables/rules.v4 > /dev/null
        
        show_message "success" "IPTables forwarding rules have been removed."
    else
        show_message "info" "Uninstallation cancelled."
    fi
    pause_for_key
}