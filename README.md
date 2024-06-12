# Port-Shifter

Port Shifter is a script designed to manage iptables, GOST, Xray, and HAProxy installations on a Linux server. It provides an easy-to-use interface for setting up these services, checking their status, and uninstalling them.

## Features
- IPTables: Configure iptables rules for TCP and UDP ports.
- GOST: Set up a secure tunnel with GOST.
- Xray: Install and configure Xray for enhanced security.
- HAProxy: Install and configure HAProxy for load balancing.
- DNS Configuration: Update DNS server settings.
- System Updates: Keep your server up-to-dat

## Install
```shell
bash <(curl https://raw.githubusercontent.com/H-Return/Port-Shifter/main/install.sh)
```

# Usage
The script provides a dialog-based interface for managing various services. Below are the available functions:

### IPTables
1.Install IPTables:

- Configures iptables rules for TCP and UDP ports.
- Prompts for server IP and ports to be configured.

2.Check IPTables Ports:
  
- Displays the current iptables rules and service status.

3.Uninstall IPTables:

- Removes iptables rules and stops the service.

### GOST

1.Install GOST:

- Downloads and installs GOST.
- Prompts for domain/IP and port configuration.

2.Check GOST Ports:

- Displays the current GOST ports and service status.

3.Add Another Port to GOST:

- Adds a new port and domain/IP to the existing GOST configuration.

4.Uninstall GOST:

- Stops and removes GOST service and binary.
### Xray

1.Install Xray:

- Installs Xray using the official script.
- Prompts for domain/IP and port configuration.

2.Check Xray Service:

- Displays the current Xray ports and service status.
- Add Another Inbound:
- Adds a new inbound configuration to Xray.

3.Remove Inbound:

- Removes an existing inbound configuration from Xray.
- Uninstall Xray:

4.Removes Xray configuration and uninstalls the service.

### HAProxy
1.Install HAProxy:

- Installs HAProxy and configures it based on user input.

2.Check HAProxy:

- Displays the current HAProxy ports and service status.

3.Uninstall HAProxy:

- Stops and removes HAProxy service and configuration.
### Options
1.Configure DNS:

- Updates DNS server settings.

2.Update Server:

- Updates the server's package list and installed packages.


## Notes
- Ensure you have a backup of your current iptables rules and configurations before running this script.
- Running this script will modify system configurations and install various services. Use with caution on production servers.
