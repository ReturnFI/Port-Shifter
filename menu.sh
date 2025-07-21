#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root or with sudo."
  exit
fi

for script in /opt/Port-Shifter/scripts/*.sh; do
  source "$script"
done

prompt_for_input() {
    local prompt_message="$1"
    local variable_name="$2"
    echo -e -n "${YELLOW}$prompt_message ${NC}"
    read -r "$variable_name"
}

iptables_menu() {
    while true; do
        clear
        show_message "info" "================== IP-Tables Menu =================="
        echo " 1. Install IP-Tables Rules"
        echo " 2. Check Ports In Use (Status)"
        echo " 3. Uninstall IP-Tables Rules"
        echo " b. Back to Main Menu"
        echo " q. Quit"
        show_message "info" "===================================================="
        prompt_for_input "Enter your choice:" choice

        case $choice in
            1) install_iptables ;;
            2) check_port_iptables ;;
            3) uninstall_iptables ;;
            b|B) break ;;
            q|Q) exit 0 ;;
            *) show_message "error" "Invalid option, please try again." && sleep 2 ;;
        esac
    done
}

gost_menu() {
    while true; do
        clear
        show_message "info" "==================== GOST Menu ====================="
        echo " 1. Install GOST"
        echo " 2. Check GOST Status & Ports"
        echo " 3. Add Port & Domain"
        echo " 4. Remove Port & Domain"
        echo " 5. Uninstall GOST"
        echo " b. Back to Main Menu"
        echo " q. Quit"
        show_message "info" "===================================================="
        prompt_for_input "Enter your choice:" choice

        case $choice in
            1) install_gost ;;
            2) check_port_gost ;;
            3) add_port_gost ;;
            4) remove_port_gost ;;
            5) uninstall_gost ;;
            b|B) break ;;
            q|Q) exit 0 ;;
            *) show_message "error" "Invalid option, please try again." && sleep 2 ;;
        esac
    done
}

dokodemo_menu() {
    while true; do
        clear
        show_message "info" "================ Dokodemo-Door Menu ================"
        echo " 1. Install Xray (Dokodemo-Door)"
        echo " 2. Check Xray Service Status"
        echo " 3. View Inbound Traffic Statistics"
        echo " 4. Add Another Inbound"
        echo " 5. Remove an Inbound"
        echo " 6. Uninstall Xray"
        echo " b. Back to Main Menu"
        echo " q. Quit"
        show_message "info" "===================================================="
        prompt_for_input "Enter your choice:" choice

        case $choice in
            1) install_xray ;;
            2) check_service_xray ;;
            3) trafficstat ;;
            4) add_another_inbound ;;
            5) remove_inbound ;;
            6) uninstall_xray ;;
            b|B) break ;;
            q|Q) exit 0 ;;
            *) show_message "error" "Invalid option, please try again." && sleep 2 ;;
        esac
    done
}

haproxy_menu() {
    while true; do
        clear
        show_message "info" "=================== HAProxy Menu ==================="
        echo " 1. Install HAProxy"
        echo " 2. Check HAProxy Status & Port"
        echo " 3. Add Tunnel Configuration"
        echo " 4. Remove Tunnel Configuration"
        echo " 5. Uninstall HAProxy"
        echo " b. Back to Main Menu"
        echo " q. Quit"
        show_message "info" "===================================================="
        prompt_for_input "Enter your choice:" choice

        case $choice in
            1) install_haproxy ;;
            2) check_haproxy ;;
            3) add_frontend_backend ;;
            4) remove_frontend_backend ;;
            5) uninstall_haproxy ;;
            b|B) break ;;
            q|Q) exit 0 ;;
            *) show_message "error" "Invalid option, please try again." && sleep 2 ;;
        esac
    done
}

other_options_menu() {
    while true; do
        clear
        show_message "info" "================ Other Options Menu ================"
        echo " 1. Configure DNS"
        echo " 2. Update Server Packages"
        echo " 3. Ping Test"
        echo " b. Back to Main Menu"
        echo " q. Quit"
        show_message "info" "===================================================="
        prompt_for_input "Enter your choice:" choice

        case $choice in
            1) configure_dns ;;
            2) update_server ;;
            3) ping_websites ;;
            b|B) break ;;
            q|Q) exit 0 ;;
            *) show_message "error" "Invalid option, please try again." && sleep 2 ;;
        esac
    done
}

# --- Main Menu ---
main_menu() {
    while true; do
        clear
        show_message "info" "=============== Port-Shifter Main Menu ==============="
        show_message "info" "        Choose your tunnel mode or option"
        show_message "info" "========================================================"
        echo " 1. IP-Tables Tunnel"
        echo " 2. GOST Tunnel"
        echo " 3. Dokodemo-Door (Xray) Tunnel"
        echo " 4. HA-Proxy Tunnel"
        echo " 5. Other Options"
        echo " q. Quit"
        show_message "info" "========================================================"
        prompt_for_input "Enter your choice:" choice

        case $choice in
            1) iptables_menu ;;
            2) gost_menu ;;
            3) dokodemo_menu ;;
            4) haproxy_menu ;;
            5) other_options_menu ;;
            q|Q) clear; show_message "info" "Exiting Port-Shifter. Goodbye!"; exit 0 ;;
            *) show_message "error" "Invalid option, please try again." && sleep 2 ;;
        esac
    done
}

# Start the main menu
main_menu