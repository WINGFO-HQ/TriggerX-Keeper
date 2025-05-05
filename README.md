# TriggerX Keeper Installer

This repository provides an automated installation script to set up a **TriggerX Keeper Node**, which participates in the TriggerX AVS (Actively Validated Services) ecosystem on EigenLayer.

## 📦 Features

- Installs required dependencies (Docker, Node.js v22.6.0, othentic-cli)
- Configures environment variables securely
- Detects public IP and Peer ID automatically
- Supports Grafana and monitoring tools
- Compatible with **mainnet** and **testnet** setups
- Cleans up after installation

## 🚀 Quick Install

Run the following command to install and configure your Keeper node:
- ✅ Using `curl`:
```bash
rm -f triggerx_keeper_install.sh && curl -o triggerx_keeper_install.sh https://raw.githubusercontent.com/WINGFO-HQ/TriggerX-Keeper/refs/heads/main/triggerx_keeper_install.sh && chmod +x triggerx_keeper_install.sh && ./triggerx_keeper_install.sh && rm -f triggerx_keeper_install.sh
```
- ✅ Using `wget`:
```bash
rm -f triggerx_keeper_install.sh && wget -O triggerx_keeper_install.sh https://raw.githubusercontent.com/WINGFO-HQ/TriggerX-Keeper/refs/heads/main/triggerx_keeper_install.sh && chmod +x triggerx_keeper_install.sh && ./triggerx_keeper_install.sh && rm -f triggerx_keeper_install.sh
```
