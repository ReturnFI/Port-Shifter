#!/bin/bash

# Define color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

show_message() {
    local type="$1"
    local message="$2"
    
    case "$type" in
        "error")
            echo -e "${RED}Error: ${message}${NC}"
            ;;
        "success")
            echo -e "${GREEN}Success: ${message}${NC}"
            ;;
        "info")
            echo -e "${BLUE}Info: ${message}${NC}"
            ;;
        "warning")
            echo -e "${YELLOW}Warning: ${message}${NC}"
            ;;
        *)
            echo -e "${message}"
            ;;
    esac
}


if [ -f /etc/redhat-release ]; then
    if grep -q "Rocky" /etc/redhat-release; then
        OS="Rocky"
    elif grep -q "AlmaLinux" /etc/redhat-release; then
        OS="AlmaLinux"
    else
        OS="CentOS"
    fi
elif [ -f /etc/os-release ]; then
    . /etc/os-release
    case "$ID" in
        ubuntu)
            OS="Ubuntu"
            ;;
        debian)
            OS="Debian"
            ;;
        fedora)
            OS="Fedora"
            ;;
        *)
            show_message "error" "Unsupported OS: $ID"
            exit 1
            ;;
    esac
else
    show_message "error" "Unsupported OS."
    exit 1
fi

case "$OS" in
    "Ubuntu"|"Debian")
        PACKAGE_MANAGER="apt"
        SERVICE_MANAGER="systemctl"
        ;;
    "Rocky"|"AlmaLinux"|"Fedora")
        PACKAGE_MANAGER="dnf"
        SERVICE_MANAGER="systemctl"
        ;;
    "CentOS")
        PACKAGE_MANAGER="yum"
        SERVICE_MANAGER="systemctl"
        ;;
    *)
        show_message "error" "Unsupported OS: $OS"
        exit 1
        ;;
esac