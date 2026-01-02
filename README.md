
# Secure Network Infrastructure (Zero Trust Implementation)

## 📌 Project Overview
This project involves the design, simulation, and security analysis of a critical network infrastructure based on the **Zero Trust** model. The entire architecture is emulated using **Mininet** and implements advanced security mechanisms including:

*   **Network Segmentation** (5 distinct zones).
*   **Zone-Based Policy Firewall** (iptables).
*   **Encrypted Web Services** (HTTPS/TLS with forced redirection).
*   **Secure Remote Access** (OpenVPN).

**Course:** Network Security (LSI3)  
**Environment:** Linux Debian (Virtual Machine) / Mininet

---

## 🏗 Architecture
The network is centralized around a Linux Router/Firewall connecting 5 isolated zones:

1.  **WAN (10.0.0.0/24):** Simulated External Internet.
2.  **DMZ (10.0.1.0/24):** Publicly accessible services (Web Server).
3.  **LAN (10.0.2.0/24):** Internal private network.
4.  **VPN (10.0.3.0/24):** Gateway for remote secure access.
5.  **Admin (10.0.4.0/24):** Restricted management zone.

---

## ⚙️ Prerequisites

Before running the simulation, ensure your Debian/Ubuntu VM has the necessary packages:

```bash
# Update system
sudo apt-get update

# Install Mininet and OpenvSwitch controller
sudo apt-get install -y mininet openvswitch-testcontroller

# Install Security Tools
sudo apt-get install -y iptables openvpn openssl curl

# Fix for Mininet controller (if necessary on Debian)
sudo ln -s /usr/bin/ovs-testcontroller /usr/bin/controller
```

---

## 🚀 Installation & Usage

### 1. Clone the Repository
```bash
cd /root/
git clone https://github.com/SafaeHammouch/secure-network-infrastructure.git
cd secure-network-infrastructure
```

### 2. Start the Network Topology
This script builds the virtual switching infrastructure and links the nodes.
```bash
cd 00_Topologie
sudo python3 topo.py
```
*You will enter the `mininet>` CLI.*

---

## 🛡️ Step-by-Step Configuration (Inside Mininet)

Once inside the Mininet CLI (`mininet>`), follow these steps to activate the security layers.

### Phase 1: Activate Zero Trust Firewall
By default, the router might allow traffic. We must apply the **DROP all** policy and only allow specific flows.

```bash
mininet> fw /root/secure-network-infrastructure/01_Firewall/rules.sh
```
> **Verification:** 
> *   `pingall` might show packet loss (10-20% due to limiting) or success depending on config.
> *   **Critical Test:** `h_wan` cannot access `h_lan` (Connection Refused/Timeout).

### Phase 2: Deploy Secure Web Service (DMZ)
1. **Starts a Python-based Web Server that forces HTTP connections to redirect to HTTPS.**

```bash
mininet> h_dmz cd /root/secure-network-infrastructure/02_Services_DMZ && ./install_web.sh &
```
2. **Verify the ports**
```bash
mininet> h_dmz ss -tuln
```
the two ports 443 and 80 should be listening.

4. 
> **Verification:**
> *   From WAN (Insecure): `h_wan curl -v http://10.0.1.2` (Should return **301 Moved Permanently**).
> *   From WAN (Secure): `h_wan curl -k https://10.0.1.2` (Should return HTML content).

### Phase 3: Establish Secure Remote Access (VPN)
Sets up an OpenVPN tunnel between the external user (`h_wan`) and the internal VPN gateway (`h_vpn`).

1.  **Generate Keys & Configs (Automatic):**
    ```bash
    mininet> h_vpn cd /root/secure-network-infrastructure/03_VPN && ./setup_vpn.sh
    ```

2.  **Start VPN Server:**
    ```bash
    mininet> h_vpn cd /root/secure-network-infrastructure/03_VPN && openvpn --config server.conf &
    ```

3.  **Start VPN Client (External User):**
    ```bash
    mininet> h_wan cd /root/secure-network-infrastructure/03_VPN && openvpn --config client.conf &
    ```

> **Verification:**
> Wait 5 seconds, then ping the **virtual IP** inside the tunnel:
> ```bash
> mininet> h_wan ping -c 3 10.8.0.1
> ```
> *Result: 0% Packet Loss indicates the encrypted tunnel is active.*

---

## 📂 Project Structure

```text
secure-network-infrastructure/
├── 00_Topologie/
│   └── topo.py            # Mininet Python script (Network Definition)
├── 01_Firewall/
│   └── rules.sh           # iptables script (Zero Trust Logic)
├── 02_Services_DMZ/
│   ├── install_web.sh     # Launcher for Web Server
│   ├── secure_server.py   # Python HTTPS Server with Redirection logic
│   └── generate_ssl.sh    # Script to generate X.509 Certificates
├── 03_VPN/
│   ├── setup_vpn.sh       # Script to install OpenVPN & generate keys
│   └── (Generated configs: server.conf, client.conf, static.key)
└── README.md              # Documentation
```

## 📝 Authors
*   **Safae Hammouch**
*   **Zakaria Azzarkan**

---
