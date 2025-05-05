#!/bin/bash

# Enable strict error checking
set -e

# Terminal colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Banner function
display_banner() {
    clear
    echo ""
    echo -e "${CYAN}=============================================="
    echo "  _______   _                           __   __"
    echo " |__   __| (_)                         \\  \\ /  /"
    echo "    | |_ __ _  __ _  __ _  ___ _ __    \\  V  / "
    echo "    | | '__| |/ _\` |/ _\` |/ _ \\ '__|    >   <  "
    echo "    | | |  | | (_| | (_| |  __/ |      /  .  \\ "
    echo "    |_|_|  |_|\\__, |\\__, |\\___|_|     /__/ \\__\\"
    echo "               __/ | __/ |                     "
    echo "              |___/ |___/                      "
    echo ""
    echo "==============================================="
    echo -e " ${GREEN}WINGFO TriggerX ${CYAN} Keeper Auto Installer"
    echo -e "==============================================${NC}"
    echo ""
}

# Progress indicator
show_progress() {
    local message="$1"
    echo -e "${YELLOW}⏳ ${message}...${NC}"
}

# Success message
show_success() {
    local message="$1"
    echo -e "${GREEN}✅ ${message}${NC}"
}

# Error message and exit
show_error_and_exit() {
    local message="$1"
    echo -e "${RED}❌ ERROR: ${message}${NC}"
    exit 1
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check for ethereum address format
validate_eth_address() {
    local address="$1"
    if [[ ! "$address" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
        echo -e "${RED}Invalid Ethereum address format. It should be 0x followed by 40 hex characters.${NC}"
        return 1
    fi
    return 0
}

# Check for private key format
validate_private_key() {
    local pkey="$1"
    # Simple check for hexadecimal format with 0x prefix and 64 hex chars
    if [[ ! "$pkey" =~ ^0x[a-fA-F0-9]{64}$ ]]; then
        echo -e "${RED}Invalid private key format. It should be 0x followed by 64 hex characters.${NC}"
        return 1
    fi
    return 0
}

# Validate URL endpoints
validate_rpc_endpoint() {
    local rpc="$1"
    if [[ ! "$rpc" =~ ^https?:// ]]; then
        echo -e "${RED}Invalid RPC endpoint. URL should start with http:// or https://${NC}"
        return 1
    fi
    return 0
}

# Check system requirements
check_system_requirements() {
    show_progress "Checking system requirements"
    
    # Check OS
    if [[ "$(uname)" != "Linux" ]]; then
        show_error_and_exit "This script only works on Linux"
    fi
    
    # Check minimum RAM (8GB recommended)
    local ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local ram_gb=$((ram_kb / 1024 / 1024))
    
    if [ "$ram_gb" -lt 4 ]; then
        echo -e "${RED}Warning: Your system has less than 4GB RAM (${ram_gb}GB). 8GB or more is recommended for optimal performance.${NC}"
        read -p "Continue anyway? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Check disk space (at least 50GB free recommended)
    local free_disk_kb=$(df -k --output=avail "$HOME" | tail -n1)
    local free_disk_gb=$((free_disk_kb / 1024 / 1024))
    
    if [ "$free_disk_gb" -lt 20 ]; then
        echo -e "${RED}Warning: You have less than 20GB free disk space (${free_disk_gb}GB). 50GB or more is recommended.${NC}"
        read -p "Continue anyway? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    show_success "System requirements check completed"
}

# Install dependencies
install_dependencies() {
    show_progress "Installing system dependencies"
    
    # Update package lists
    sudo apt-get update -qq
    
    # Install dependencies
    sudo apt-get install -y git curl wget build-essential
    
    # Install Docker if not already installed
    if ! command_exists docker; then
        show_progress "Installing Docker"
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        sudo usermod -aG docker "$USER"
        rm get-docker.sh
        show_success "Docker installed"
    else
        show_success "Docker already installed"
    fi
    
    # Install Docker Compose if not already installed
    if ! command_exists docker-compose; then
        show_progress "Installing Docker Compose"
        sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        show_success "Docker Compose installed"
    else
        show_success "Docker Compose already installed"
    fi
    
    # Install Node.js
    if ! command_exists node; then
        show_progress "Installing Node.js"
        curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
        sudo apt-get install -y nodejs
        show_success "Node.js installed"
    else
        # Check Node.js version
        node_version=$(node -v | cut -d 'v' -f 2 | cut -d '.' -f 1)
        if [ "$node_version" -lt 22 ]; then
            show_progress "Upgrading Node.js to v22"
            curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
            sudo apt-get install -y nodejs
            show_success "Node.js upgraded to v22"
        else
            show_success "Node.js v22+ already installed"
        fi
    fi
    
    # Install Othentic CLI
    show_progress "Installing Othentic CLI"
    npm install -g @othentic/othentic-cli@1.10.0
    
    show_success "All dependencies installed successfully"
}

# Get user input with validation
get_user_input() {
    show_progress "Configuring TriggerX Keeper"
    
    # Get L1 RPC endpoint
    while true; do
        read -p "$(echo -e "${BLUE}Enter ETH RPC (Holesky) endpoint (Alchemy/Infura/Zan.Top): ${NC}")" L1_RPC
        if validate_rpc_endpoint "$L1_RPC"; then
            break
        fi
    done
    
    # Get L2 RPC endpoint
    while true; do
        read -p "$(echo -e "${BLUE}Enter BASE RPC (Base Sepolia) endpoint: ${NC}")" L2_RPC
        if validate_rpc_endpoint "$L2_RPC"; then
            break
        fi
    done
    
    # Get private key with warning
    echo -e "${RED}WARNING: Use a separate wallet with only the necessary funds. NEVER use your main wallet.${NC}"
    while true; do
        read -s -p "$(echo -e "${BLUE}Enter your PRIVATE KEY (0x...): ${NC}")" PRIVATE_KEY
        echo
        if [ -z "$PRIVATE_KEY" ]; then
            echo -e "${RED}Private key cannot be empty.${NC}"
            continue
        fi
        
        # Add 0x prefix if missing
        if [[ ! "$PRIVATE_KEY" =~ ^0x ]]; then
            PRIVATE_KEY="0x$PRIVATE_KEY"
        fi
        
        if validate_private_key "$PRIVATE_KEY"; then
            break
        fi
    done
    
    # Get operator address
    while true; do
        read -p "$(echo -e "${BLUE}Enter your OPERATOR_ADDRESS (0x... same as your Address from Private Key): ${NC}")" OPERATOR_ADDRESS
        if validate_eth_address "$OPERATOR_ADDRESS"; then
            break
        fi
    done
    
    # Get port settings with defaults
    read -p "$(echo -e "${BLUE}Enter Operator RPC port [default: 9005]: ${NC}")" OPERATOR_RPC_PORT
    OPERATOR_RPC_PORT=${OPERATOR_RPC_PORT:-9005}
    
    read -p "$(echo -e "${BLUE}Enter Operator P2P port [default: 9006]: ${NC}")" OPERATOR_P2P_PORT
    OPERATOR_P2P_PORT=${OPERATOR_P2P_PORT:-9006}
    
    read -p "$(echo -e "${BLUE}Enter Operator Metrics port [default: 9009]: ${NC}")" OPERATOR_METRICS_PORT
    OPERATOR_METRICS_PORT=${OPERATOR_METRICS_PORT:-9009}
    
    read -p "$(echo -e "${BLUE}Enter Grafana port [default: 4000]: ${NC}")" GRAFANA_PORT
    GRAFANA_PORT=${GRAFANA_PORT:-4000}
    
    # Check if ports are available
    for port in "$OPERATOR_RPC_PORT" "$OPERATOR_P2P_PORT" "$OPERATOR_METRICS_PORT" "$GRAFANA_PORT"; do
        if netstat -tuln | grep -q ":$port "; then
            echo -e "${RED}Warning: Port $port is already in use. This may cause conflicts.${NC}"
            read -p "Continue anyway? (y/n) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    done
    
    show_success "Configuration completed"
}

# Set up TriggerX Keeper
setup_triggerx() {
    # Static configuration
    KEEPER_DIR="$HOME/triggerx"
    REPO_URL="https://github.com/trigg3rX/triggerx-keeper-setup.git"
    GOV_CONTRACT="0xE52De62Bf743493d3c4E1ac8db40f342FEb11fEa"
    
    # Clone repository
    show_progress "Cloning TriggerX repository"
    if [ -d "$KEEPER_DIR" ]; then
        read -p "$(echo -e "${YELLOW}Directory $KEEPER_DIR already exists. Delete and reinstall? (y/n) ${NC}")" -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$KEEPER_DIR"
        else
            show_error_and_exit "Installation aborted. Please backup or delete the existing directory."
        fi
    fi
    
    git clone "$REPO_URL" "$KEEPER_DIR"
    cd "$KEEPER_DIR"
    cp .env.example .env
    show_success "Repository cloned successfully"
    
    # Get VPS IP and Peer ID
    show_progress "Generating node configuration"
    PUBLIC_IPV4_ADDRESS=$(curl -s ifconfig.me)
    PEER_ID=$(othentic-cli node get-id --node-type attester | grep -oE '12D3.*')
    
    # Create .env file
    cat > .env <<EOF
L1_RPC=$L1_RPC
L2_RPC=$L2_RPC
PRIVATE_KEY=$PRIVATE_KEY
OPERATOR_ADDRESS=$OPERATOR_ADDRESS
PUBLIC_IPV4_ADDRESS=$PUBLIC_IPV4_ADDRESS
PEER_ID=$PEER_ID
OPERATOR_RPC_PORT=$OPERATOR_RPC_PORT
OPERATOR_P2P_PORT=$OPERATOR_P2P_PORT
OPERATOR_METRICS_PORT=$OPERATOR_METRICS_PORT
GRAFANA_PORT=$GRAFANA_PORT
L1_CHAIN=17000
L2_CHAIN=84532
AVS_GOVERNANCE_ADDRESS=$GOV_CONTRACT
ATTESTATION_CENTER_ADDRESS=0x8256F235Ed6445fb9f8177a847183A8C8CD97cF1
PINATA_API_KEY=3e1b278b99bd95877625
PINATA_SECRET_API_KEY=8e41503276cd848b4f95fcde1f30e325652e224e7233dcc1910e5a226675ace4
IPFS_HOST=apricot-voluntary-fowl-585.mypinata.cloud
OTHENTIC_BOOTSTRAP_ID=12D3KooWBNFG1QjuF3UKAKvqhdXcxh9iBmj88cM5eU2EK5Pa91KB
OTHENTIC_CLIENT_RPC_ADDRESS=https://aggregator.triggerx.network
HEALTH_IP_ADDRESS=https://health.triggerx.network
EOF
    
    show_success "Environment configuration created"
}

# Install and start services
start_services() {
    show_progress "Installing TriggerX services"
    ./triggerx.sh install
    
    show_progress "Starting TriggerX node"
    ./triggerx.sh start
    
    show_progress "Starting monitoring services"
    ./triggerx.sh start-mon
    
    show_success "TriggerX Keeper node is now running!"
}

# Display registration guide
display_registration_guide() {
    echo ""
    echo -e "${CYAN}=====================================================${NC}"
    echo -e "${GREEN}✅ TriggerX Keeper Node Setup Complete!${NC}"
    echo -e "${CYAN}=====================================================${NC}"
    echo ""
    echo -e "${YELLOW}📝 Next Steps for Registration:${NC}"
    echo ""
    echo -e "${BLUE}1️⃣ Register Operator on EigenLayer:${NC}"
    echo -e "   ${GREEN}othentic-cli operator register-eigenlayer${NC}"
    echo ""
    echo -e "   When prompted, enter:"
    echo -e "     - Private Key"
    echo -e "     - Operator Name, Description, Website, Logo, Twitter"
    echo -e "     - AVS Governance Address: ${GREEN}$GOV_CONTRACT${NC}"
    echo ""
    echo -e "${BLUE}2️⃣ Deposit into strategy (e.g. stETH):${NC}"
    echo -e "   ${GREEN}othentic-cli operator deposit --staking-contract stETH --amount 0.001 --convert 0.002${NC}"
    echo ""
    echo -e "${BLUE}3️⃣ Register with TriggerX:${NC}"
    echo -e "   ${GREEN}othentic-cli operator register${NC}"
    echo -e "   Use same PRIVATE_KEY and SIGNING_KEY (can be same on testnet)"
    echo ""
    echo -e "${BLUE}🌐 Access Grafana Dashboard:${NC}"
    echo -e "   ${GREEN}http://$PUBLIC_IPV4_ADDRESS:$GRAFANA_PORT${NC}"
    echo ""
    echo -e "${YELLOW}💡 For more information and troubleshooting:${NC}"
    echo -e "   ${GREEN}https://triggerx.gitbook.io/triggerx-docs/join-as-keeper${NC}"
    echo -e "   ${GREEN}https://docs.othentic.xyz/main/avs-framework/othentic-cli/private-key-management${NC}"
    echo ""
    echo -e "${CYAN}=====================================================${NC}"
}

# Main execution flow
main() {
    display_banner
    
    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        show_error_and_exit "Please do not run this script as root or with sudo"
    fi
    
    check_system_requirements
    install_dependencies
    get_user_input
    setup_triggerx
    start_services
    display_registration_guide
}

# Run the script
main
