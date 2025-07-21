#!/bin/bash

TMP_DIR=$(mktemp -d)
trap 'rm -rf -- "$TMP_DIR"' EXIT

git clone -b beta -q https://github.com/ReturnFI/Port-Shifter "$TMP_DIR/Port-Shifter"
source "$TMP_DIR/Port-Shifter/scripts/package.sh"

if ! sudo -n true 2>/dev/null; then
    show_message "error" "This script requires sudo permissions. Please run it as a user with sudo privileges."
    exit 1
else
    show_message "success" "Sudo permissions verified."
fi

show_message "info" "Detected OS: $OS, Package Manager: $PACKAGE_MANAGER"

if [ "$PACKAGE_MANAGER" = "apt" ]; then
    show_message "info" "Updating server..."
    if  apt update -qq > /dev/null 2>&1; then
        show_message "success" "Server updated successfully."
    else
        show_message "error" "Failed to update server."
        exit 1
    fi
else
    show_message "info" "Updating server..."
    if  $PACKAGE_MANAGER update -y -q > /dev/null 2>&1; then
        show_message "success" "Server updated successfully."
    else
        show_message "error" "Failed to update server."
        exit 1
    fi
fi

necessary_packages=(
    jq
    lsof
    tar
    wget
    git
    curl
)

install_package() {
    local package=$1
    if ! command -v "$package" &> /dev/null; then
        echo -n -e "${BLUE}Info: Installing $package... ${NC}"
        if  $PACKAGE_MANAGER install "$package" -y -qq > /dev/null 2>&1; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${RED}✗${NC}"
            show_message "error" "Failed to install $package. Aborting."
            exit 1
        fi
    else
        show_message "success" "$package is already installed."
    fi
}

show_message "info" "Checking for necessary packages..."
for package in "${necessary_packages[@]}"; do
    install_package "$package"
done

INSTALL_DIR="/opt/Port-Shifter"
show_message "info" "Installing Port-Shifter to $INSTALL_DIR..."
if [ -d "$INSTALL_DIR" ]; then
    show_message "warning" "Existing installation found at $INSTALL_DIR. It will be overwritten."
     rm -rf "$INSTALL_DIR"
fi
 mv "$TMP_DIR/Port-Shifter" /opt/
 chmod +x /opt/Port-Shifter/*.sh
 chmod +x /opt/Port-Shifter/scripts/*.sh

# --- Alias Setup ---
BASHRC_FILE="$HOME/.bashrc"
ALIAS_CMD="alias portshift=' /opt/Port-Shifter/menu.sh'"
if ! grep -qF "$ALIAS_CMD" "$BASHRC_FILE"; then
    show_message "info" "Adding 'portshift' alias to $BASHRC_FILE..."
    echo "" >> "$BASHRC_FILE"
    echo "# Port-Shifter Alias" >> "$BASHRC_FILE"
    echo "$ALIAS_CMD" >> "$BASHRC_FILE"
    show_message "success" "Alias added."
    show_message "warning" "Please run 'source ~/.bashrc' or restart your terminal to use the 'portshift' command."
else
    show_message "success" "'portshift' alias already exists."
fi

sleep 2
clear
show_message "success" "Installation complete!"
show_message "info" "You can now run the menu by typing:  /opt/Port-Shifter/menu.sh"
show_message "info" "Or, after sourcing .bashrc, simply type: portshift"