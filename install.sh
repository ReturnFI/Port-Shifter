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
