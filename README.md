# Port-Shifter

Port Shifter is a script designed to manage iptables, GOST, Xray, and HAProxy installations on a Linux server. It provides an easy-to-use interface for setting up these services, checking their status, and uninstalling them.

<div style="text-align:center;"><img style="aspect-ratio:1448/659;" src="https://github.com/H-Return/Port-Shifter/assets/151555003/e94952f8-f85b-4241-83b9-a2e9b7958b8b" width="600" height="300"></div>


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

<details>
<summary><b>IPTables</b></summary>
1.Install IPTables:

- Configures iptables rules for TCP and UDP ports.
- Prompts for server IP and ports to be configured.

2.Check IPTables Ports:
  
- Displays the current iptables rules and service status.

3.Uninstall IPTables:

- Removes iptables rules and stops the service.
</details>
<details>
<summary><b>GOST</b></summary>

1.Install GOST:

- Downloads and installs GOST.
- Prompts for domain/IP and port configuration.

2.Check GOST Ports:

- Displays the current GOST ports and service status.

3.Add Another Port to GOST:

- Adds a new port and domain/IP to the existing GOST configuration.

4.Uninstall GOST:

- Stops and removes GOST service and binary.
</details>
<details>
<summary><b>Xray</b></summary>

1.Install Xray:

- Installs Xray using the official script.
- Prompts for domain/IP and port configuration.

2.Check Xray Service:

- Displays the current Xray ports and service status.

3.Add Another Inbound:

- Adds a new inbound configuration to Xray.

4.Remove Inbound:

- Removes an existing inbound configuration from Xray.

5.Uninstall Xray:

- Removes Xray configuration and uninstalls the service.
</details>
<details>
<summary><b>HAProxy</b></summary>
1.Install HAProxy:

- Installs HAProxy and configures it based on user input.

2.Check HAProxy:

- Displays the current HAProxy ports and service status.

3.Uninstall HAProxy:

- Stops and removes HAProxy service and configuration.
</details>

<details>
<summary><b>Options</b></summary>
1.Configure DNS:

- Updates DNS server settings.

2.Update Server:

- Updates the server's package list and installed packages.
</details>

## Notes
- Ensure you have a backup of your current iptables rules and configurations before running this script.
- Running this script will modify system configurations and install various services. Use with caution on production servers.
