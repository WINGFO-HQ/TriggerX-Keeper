#!/bin/bash

set -euo pipefail

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
    echo -e " ${GREEN}WINGFO${CYAN} TriggerX Keeper Auto Installer"
    echo -e "==============================================${NC}"
    echo ""
}

show_progress() {
    local message="$1"
    echo -e "${YELLOW}⏳ ${message}...${NC}"
}

show_success() {
    local message="$1"
    echo -e "${GREEN}✅ ${message}${NC}"
}

show_error_and_exit() {
    local message="$1"
    echo -e "${RED}❌ ERROR: ${message}${NC}"
    exit 1
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

validate_eth_address() {
    local address="$1"
    if [[ ! "$address" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
        echo -e "${RED}Invalid Ethereum address format. It should be 0x followed by 40 hex characters.${NC}"
        return 1
    fi
    return 0
}

validate_private_key() {
    local pkey="$1"
    if [[ ! "$pkey" =~ ^0x[a-fA-F0-9]{64}$ ]]; then
        echo -e "${RED}Invalid private key format. It should be 0x followed by 64 hex characters.${NC}"
        return 1
    fi
    return 0
}

validate_rpc_endpoint() {
    local rpc="$1"
    if [[ ! "$rpc" =~ ^https?:// ]]; then
        echo -e "${RED}Invalid RPC endpoint. URL should start with http:// or https://${NC}"
        return 1
    fi
    return 0
}

check_system_requirements() {
    show_progress "Checking system requirements"

    if [[ "$(uname)" != "Linux" ]]; then
        show_error_and_exit "This script only works on Linux"
    fi

    local ram_kb
    ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local ram_gb=$((ram_kb / 1024 / 1024))

    if [ "$ram_gb" -lt 4 ]; then
        echo -e "${RED}Warning: Your system has less than 4GB RAM (${ram_gb}GB). 8GB or more is recommended for optimal performance.${NC}"
        read -rp "Continue anyway? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi

    local free_disk_kb
    free_disk_kb=$(df -k --output=avail "$HOME" | tail -n1)
    local free_disk_gb=$((free_disk_kb / 1024 / 1024))

    if [ "$free_disk_gb" -lt 20 ]; then
        echo -e "${RED}Warning: You have less than 20GB free disk space (${free_disk_gb}GB). 50GB or more is recommended.${NC}"
        read -rp "Continue anyway? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi

    show_success "System requirements check completed"
}

install_dependencies() {
    show_progress "Checking system dependencies"

    sudo apt-get update -qq

    for pkg in git curl wget build-essential; do
        if ! dpkg -l | grep -q "ii  $pkg "; then
            show_progress "Installing $pkg"
            sudo apt-get install -y "$pkg"
            show_success "$pkg installed"
        else
            echo -e "${GREEN}$pkg already installed, skipping${NC}"
        fi
    done

    if ! command_exists docker; then
        show_progress "Installing Docker"
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        sudo usermod -aG docker "$USER"
        rm get-docker.sh
        show_success "Docker installed"
        echo -e "${YELLOW}Note: You may need to log out and back in for Docker group changes to take effect${NC}"
    else
        show_success "Docker already installed, skipping"
    fi

    if ! groups "$USER" | grep -q '\bdocker\b'; then
        echo -e "${YELLOW}Warning: User is not in docker group. Adding now...${NC}"
        sudo usermod -aG docker "$USER"
        echo -e "${YELLOW}Note: You may need to log out and back in for Docker group changes to take effect${NC}"
    fi

    if ! command_exists docker-compose; then
        show_progress "Installing Docker Compose"
        sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        show_success "Docker Compose installed"
    else
        show_success "Docker Compose already installed, skipping update"
    fi

    if ! command_exists node; then
        show_progress "Installing Node.js v22.x"
        curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
        sudo apt-get install -y nodejs
        show_success "Node.js installed"
    else
        node_version=$(node -v | cut -d 'v' -f 2 | cut -d '.' -f 1)
        if [ "$node_version" -lt 22 ]; then
            show_progress "Upgrading Node.js to v22"
            curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
            sudo apt-get install -y nodejs
            show_success "Node.js upgraded to v22"
        else
            show_success "Node.js $(node -v) already installed, skipping"
        fi
    fi

    if ! command_exists othentic-cli || [[ $(othentic-cli --version 2>/dev/null | grep -o -E '[0-9]+\.[0-9]+\.[0-9]+' | head -1) != "1.10.0" ]]; then
        show_progress "Installing Othentic CLI v1.10.0"
        npm install -g @othentic/othentic-cli@1.10.0
        show_success "Othentic CLI v1.10.0 installed"
    else
        show_success "Othentic CLI v1.10.0 already installed, skipping"
    fi

    show_success "All dependencies installed successfully"
}

get_user_input() {
    show_progress "Configuring TriggerX Keeper"

    while true; do
        read -rp "$(echo -e "${BLUE}Enter ETH RPC (Holesky) endpoint (Alchemy/Infura/Zan.Top): ${NC}")" L1_RPC
        if validate_rpc_endpoint "$L1_RPC"; then
            break
        fi
    done

    while true; do
        read -rp "$(echo -e "${BLUE}Enter BASE RPC (Base Sepolia) endpoint: ${NC}")" L2_RPC
        if validate_rpc_endpoint "$L2_RPC"; then
            break
        fi
    done

    echo -e "${RED}WARNING: Use a separate wallet with only the necessary funds. NEVER use your main wallet.${NC}"
    while true; do
        read -srp "$(echo -e "${BLUE}Enter your PRIVATE KEY (EVM or ETH Private Key): ${NC}")" PRIVATE_KEY
        echo
        if [ -z "$PRIVATE_KEY" ]; then
            echo -e "${RED}Private key cannot be empty.${NC}"
            continue
        fi
        if [[ ! "$PRIVATE_KEY" =~ ^0x ]]; then
            PRIVATE_KEY="0x$PRIVATE_KEY"
        fi
        if validate_private_key "$PRIVATE_KEY"; then
            break
        fi
    done

    while true; do
        read -rp "$(echo -e "${BLUE}Enter your OPERATOR_ADDRESS (0x... same as your Address from Private Key): ${NC}")" OPERATOR_ADDRESS
        if validate_eth_address "$OPERATOR_ADDRESS"; then
            break
        fi
    done

    read -rp "$(echo -e "${BLUE}Enter Operator RPC port [default: 9005]: ${NC}")" OPERATOR_RPC_PORT
    OPERATOR_RPC_PORT=${OPERATOR_RPC_PORT:-9005}

    read -rp "$(echo -e "${BLUE}Enter Operator P2P port [default: 9006]: ${NC}")" OPERATOR_P2P_PORT
    OPERATOR_P2P_PORT=${OPERATOR_P2P_PORT:-9006}

    read -rp "$(echo -e "${BLUE}Enter Operator Metrics port [default: 9009]: ${NC}")" OPERATOR_METRICS_PORT
    OPERATOR_METRICS_PORT=${OPERATOR_METRICS_PORT:-9009}

    read -rp "$(echo -e "${BLUE}Enter Grafana port [default: 4000]: ${NC}")" GRAFANA_PORT
    GRAFANA_PORT=${GRAFANA_PORT:-4000}

    for port in "$OPERATOR_RPC_PORT" "$OPERATOR_P2P_PORT" "$OPERATOR_METRICS_PORT" "$GRAFANA_PORT"; do
        if netstat -tuln 2>/dev/null | grep -q ":$port " || ss -tuln 2>/dev/null | grep -q ":$port "; then
            echo -e "${RED}Warning: Port $port is already in use. This may cause conflicts.${NC}"
            read -rp "Continue anyway? (y/n) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    done

    show_success "Configuration completed"
}

setup_triggerx() {
    KEEPER_DIR="$HOME/triggerx"
    REPO_URL="https://github.com/trigg3rX/triggerx-keeper-setup.git"
    GOV_CONTRACT="0xE52De62Bf743493d3c4E1ac8db40f342FEb11fEa"
    REPO_ACTION=""

    if [ -d "$KEEPER_DIR" ]; then
        echo -e "${YELLOW}TriggerX directory already exists at $KEEPER_DIR${NC}"
        read -rp "$(echo -e "${BLUE}What would you like to do? [r]einstall, [u]pdate, or [s]kip: ${NC}")" -n 1 -r REPO_ACTION
        echo

        case "$REPO_ACTION" in
            [Rr]*)
                show_progress "Reinstalling TriggerX repository"
                rm -rf "$KEEPER_DIR"
                git clone "$REPO_URL" "$KEEPER_DIR"
                cd "$KEEPER_DIR"
                cp .env.example .env
                ;;
            [Uu]*)
                show_progress "Updating TriggerX repository"
                cd "$KEEPER_DIR"
                git fetch
                git pull
                ;;
            [Ss]*)
                show_progress "Skipping repository setup, using existing installation"
                cd "$KEEPER_DIR"
                ;;
            *)
                show_error_and_exit "Invalid option. Please restart the script."
                ;;
        esac
    else
        show_progress "Cloning TriggerX repository"
        git clone "$REPO_URL" "$KEEPER_DIR"
        cd "$KEEPER_DIR"
        cp .env.example .env
    fi

    show_success "Repository setup completed"

    if [ -f "$KEEPER_DIR/.env" ] && [[ "${REPO_ACTION,,}" != "r" ]]; then
        echo -e "${YELLOW}Configuration file (.env) already exists${NC}"
        read -rp "$(echo -e "${BLUE}Would you like to reconfigure? (y/n): ${NC}")" -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            show_success "Using existing configuration"
            return
        fi
    fi

    show_progress "Getting public IP address"
    echo -e "${YELLOW}Running: curl -s ipinfo.io/ip${NC}"
    PUBLIC_IPV4_ADDRESS=$(curl -s ipinfo.io/ip)
    echo -e "${GREEN}Your public IP: $PUBLIC_IPV4_ADDRESS${NC}"

    show_progress "Generating peer ID"
    echo -e "${YELLOW}Running: othentic-cli node get-id --node-type attester inside a screen session...${NC}"
    othentic-cli node get-id --node-type attester

    echo -e "${BLUE}Now paste the Peer ID shown above and press Enter:${NC}"
    read -r PEER_ID
    echo -e "${GREEN}Saved PEER${NC}"

    show_progress "Creating .env configuration file"
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

check_service_status() {
    local service_name="$1"
    if docker ps --format '{{.Names}}' | grep -q "$service_name"; then
        return 0
    else
        return 1
    fi
}

start_services() {
    if check_service_status "triggerx-keeper"; then
        echo -e "${YELLOW}TriggerX Keeper is already running${NC}"
        read -rp "$(echo -e "${BLUE}Would you like to restart the services? (y/n): ${NC}")" -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            show_progress "Stopping TriggerX services"
            ./triggerx.sh stop
            show_progress "Installing and restarting TriggerX services"
            ./triggerx.sh install
            ./triggerx.sh start
        else
            show_success "Keeping existing TriggerX services running"
        fi
    else
        show_progress "Installing TriggerX services"
        ./triggerx.sh install
        show_progress "Starting TriggerX node"
        ./triggerx.sh start
    fi

    if check_service_status "triggerx-prometheus" || check_service_status "triggerx-grafana"; then
        echo -e "${YELLOW}Monitoring services are already running${NC}"
        read -rp "$(echo -e "${BLUE}Would you like to restart the monitoring services? (y/n): ${NC}")" -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            show_progress "Stopping monitoring services"
            ./triggerx.sh stop-mon
            show_progress "Starting monitoring services"
            ./triggerx.sh start-mon
        else
            show_success "Keeping existing monitoring services running"
        fi
    else
        show_progress "Starting monitoring services"
        ./triggerx.sh start-mon
    fi

    show_success "TriggerX Keeper node is now running!"
}

display_registration_guide() {
    if [ -z "${PUBLIC_IPV4_ADDRESS:-}" ] && [ -f .env ]; then
        PUBLIC_IPV4_ADDRESS=$(grep "PUBLIC_IPV4_ADDRESS" .env | cut -d '=' -f2)
    fi
    if [ -z "${GRAFANA_PORT:-}" ] && [ -f .env ]; then
        GRAFANA_PORT=$(grep "GRAFANA_PORT" .env | cut -d '=' -f2)
    fi
    if [ -z "${GOV_CONTRACT:-}" ]; then
        GOV_CONTRACT="0xE52De62Bf743493d3c4E1ac8db40f342FEb11fEa"
    fi

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
    echo -e "${BLUE}🔄 Node Management Commands:${NC}"
    echo -e "   ${GREEN}cd ~/triggerx && ./triggerx.sh status${NC} (Check node status)"
    echo -e "   ${GREEN}cd ~/triggerx && ./triggerx.sh stop${NC} (Stop node)"
    echo -e "   ${GREEN}cd ~/triggerx && ./triggerx.sh start${NC} (Start node)"
    echo -e "   ${GREEN}cd ~/triggerx && ./triggerx.sh restart${NC} (Restart node)"
    echo -e "${CYAN}=====================================================${NC}"
}

main() {
    display_banner
    check_system_requirements
    install_dependencies
    get_user_input
    setup_triggerx
    start_services
    display_registration_guide
}

main
