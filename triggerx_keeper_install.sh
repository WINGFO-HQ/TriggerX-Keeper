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

# Global variables
KEEPER_DIR="$HOME/triggerx"
REPO_URL="https://github.com/trigg3rX/triggerx-keeper-setup.git"
GOV_CONTRACT="0xE52De62Bf743493d3c4E1ac8db40f342FEb11fEa"
PRIVATE_KEY=""

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
    echo -e " ${GREEN}WINGFO${CYAN} TriggerX Keeper Menu Installer"
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

# Command exists check
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Validate private key format
validate_private_key() {
    local pkey="$1"
    # Simple check for hexadecimal format with 0x prefix and 64 hex chars
    if [[ ! "$pkey" =~ ^0x[a-fA-F0-9]{64}$ ]]; then
        echo -e "${RED}Invalid private key format. It should be 0x followed by 64 hex characters.${NC}"
        return 1
    fi
    return 0
}

# Install dependencies
install_dependencies() {
    show_progress "Checking system dependencies"
    
    # Update package lists
    sudo apt-get update -qq
    
    # Check and install basic dependencies
    for pkg in git curl wget build-essential nano; do
        if ! dpkg -l | grep -q "ii  $pkg "; then
            show_progress "Installing $pkg"
            sudo apt-get install -y $pkg
            show_success "$pkg installed"
        else
            echo -e "${GREEN}$pkg already installed, skipping${NC}"
        fi
    done
    
    # Install Docker if not already installed
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
    
    # Check if user is in docker group
    if ! groups "$USER" | grep -q '\bdocker\b'; then
        echo -e "${YELLOW}Warning: User is not in docker group. Adding now...${NC}"
        sudo usermod -aG docker "$USER"
        echo -e "${YELLOW}Note: You may need to log out and back in for Docker group changes to take effect${NC}"
    fi
    
    # Install Docker Compose if not already installed
    if ! command_exists docker-compose; then
        show_progress "Installing Docker Compose"
        sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        show_success "Docker Compose installed"
    else
        show_success "Docker Compose already installed, skipping update"
    fi
    
    # Install Node.js
    if ! command_exists node; then
        show_progress "Installing Node.js v22.x"
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
            show_success "Node.js $(node -v) already installed, skipping"
        fi
    fi
    
    # Install Othentic CLI
    if ! command_exists othentic-cli || [[ $(othentic-cli --version 2>/dev/null | grep -o -E '[0-9]+\.[0-9]+\.[0-9]+' | head -1) != "1.10.0" ]]; then
        show_progress "Installing Othentic CLI v1.10.0"
        npm install -g @othentic/othentic-cli@1.10.0
        show_success "Othentic CLI v1.10.0 installed"
    else
        show_success "Othentic CLI v1.10.0 already installed, skipping"
    fi
    
    show_success "All dependencies installed successfully"
}

# Clone or update TriggerX repository
setup_triggerx_repo() {
    # Check if repository already exists
    if [ -d "$KEEPER_DIR" ]; then
        echo -e "${YELLOW}TriggerX directory already exists at $KEEPER_DIR${NC}"
        read -p "$(echo -e "${BLUE}What would you like to do? [r]einstall, [u]pdate, or [s]kip: ${NC}")" -n 1 -r REPO_ACTION
        echo
        
        case "$REPO_ACTION" in
            [Rr]*)
                show_progress "Reinstalling TriggerX repository"
                rm -rf "$KEEPER_DIR"
                git clone "$REPO_URL" "$KEEPER_DIR"
                cd "$KEEPER_DIR"
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
        # Clone repository
        show_progress "Cloning TriggerX repository"
        git clone "$REPO_URL" "$KEEPER_DIR"
        cd "$KEEPER_DIR"
    fi
    
    show_success "Repository setup completed"
}

# Setup the .env file focusing on Peer ID
setup_env_file() {
    show_progress "Setting up environment configuration"
    
    # Make sure we're in the keeper directory
    cd "$KEEPER_DIR"
    
    # First check if .env.example exists
    if [ ! -f "$KEEPER_DIR/.env.example" ]; then
        show_error_and_exit ".env.example file not found in $KEEPER_DIR"
    fi
    
    # Copy the example file if .env doesn't exist
    if [ ! -f "$KEEPER_DIR/.env" ]; then
        echo -e "${BLUE}Copying .env.example to .env${NC}"
        cp "$KEEPER_DIR/.env.example" "$KEEPER_DIR/.env"
        show_success ".env.example copied to .env"
    else
        echo -e "${YELLOW}Using existing .env file${NC}"
    fi
    
    # Get VPS IP
    show_progress "Getting public IP address"
    PUBLIC_IPV4_ADDRESS=$(curl -s ipinfo.io/ip)
    echo -e "${GREEN}Your public IP: $PUBLIC_IPV4_ADDRESS${NC}"
    
    # Update the IP in .env
    sed -i "s|^PUBLIC_IPV4_ADDRESS=.*|PUBLIC_IPV4_ADDRESS=$PUBLIC_IPV4_ADDRESS|" "$KEEPER_DIR/.env"
    
    # Get private key for Peer ID generation
    echo -e "${RED}WARNING: Use a separate wallet with only the necessary funds. NEVER use your main wallet.${NC}"
    while true; do
        read -s -p "$(echo -e "${BLUE}Enter your PRIVATE KEY (for Peer ID generation): ${NC}")" PRIVATE_KEY
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
    
    # Update private key in .env
    sed -i "s|^PRIVATE_KEY=.*|PRIVATE_KEY=$PRIVATE_KEY|" "$KEEPER_DIR/.env"
    
    # Generate Peer ID
    show_progress "Generating peer ID"
    echo -e "${YELLOW}Running: othentic-cli node get-id --node-type attester${NC}"
    PEER_ID=$(othentic-cli node get-id --node-type attester)
    echo -e "${GREEN}Your peer ID: $PEER_ID${NC}"
    
    # Update Peer ID in .env
    sed -i "s|^PEER_ID=.*|PEER_ID=$PEER_ID|" "$KEEPER_DIR/.env"
    
    show_success "Peer ID generated and updated in .env file"
}

# Start TriggerX services
start_triggerx_services() {
    cd "$KEEPER_DIR"
    
    show_progress "Installing TriggerX services"
    ./triggerx.sh install
    
    show_progress "Starting TriggerX node"
    ./triggerx.sh start
    
    show_progress "Starting monitoring services"
    ./triggerx.sh start-mon
    
    show_success "TriggerX Keeper node is now running!"
}

# Register with TriggerX
register_triggerx() {
    cd "$KEEPER_DIR"
    
    echo -e "${CYAN}=====================================================${NC}"
    echo -e "${GREEN}TriggerX Keeper Registration${NC}"
    echo -e "${CYAN}=====================================================${NC}"
    echo ""
    
    echo -e "${YELLOW}1️⃣ Register Operator on EigenLayer:${NC}"
    echo -e "   ${GREEN}othentic-cli operator register-eigenlayer${NC}"
    echo ""
    
    read -p "$(echo -e "${BLUE}Would you like to register on EigenLayer now? (y/n): ${NC}")" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        othentic-cli operator register-eigenlayer
    fi
    
    echo ""
    echo -e "${YELLOW}2️⃣ Deposit into strategy (e.g. stETH):${NC}"
    echo -e "   ${GREEN}othentic-cli operator deposit --staking-contract stETH --amount 0.001 --convert 0.002${NC}"
    echo ""
    
    read -p "$(echo -e "${BLUE}Would you like to deposit into strategy now? (y/n): ${NC}")" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        othentic-cli operator deposit --staking-contract stETH --amount 0.001 --convert 0.002
    fi
    
    echo ""
    echo -e "${YELLOW}3️⃣ Register with TriggerX:${NC}"
    echo -e "   ${GREEN}othentic-cli operator register${NC}"
    echo ""
    
    read -p "$(echo -e "${BLUE}Would you like to register with TriggerX now? (y/n): ${NC}")" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        othentic-cli operator register
    fi
    
    show_success "Registration steps completed"
}

# Show node status
show_node_status() {
    cd "$KEEPER_DIR"
    
    echo -e "${CYAN}=====================================================${NC}"
    echo -e "${GREEN}TriggerX Keeper Status${NC}"
    echo -e "${CYAN}=====================================================${NC}"
    echo ""
    
    show_progress "Checking node status"
    ./triggerx.sh status
    
    # Get IP address and Grafana port from .env file
    local grafana_port=$(grep "GRAFANA_PORT" .env | cut -d '=' -f2)
    local pub_ip=$(grep "PUBLIC_IPV4_ADDRESS" .env | cut -d '=' -f2)
    
    echo ""
    echo -e "${BLUE}🌐 Access Grafana Dashboard:${NC}"
    echo -e "   ${GREEN}http://$pub_ip:$grafana_port${NC}"
    echo ""
    
    read -p "Press Enter to continue..."
}

# Display help information
show_help() {
    clear
    echo -e "${CYAN}=====================================================${NC}"
    echo -e "${GREEN}TriggerX Keeper Help${NC}"
    echo -e "${CYAN}=====================================================${NC}"
    echo ""
    echo -e "${BLUE}🔄 Node Management Commands:${NC}"
    echo -e "   ${GREEN}cd ~/triggerx && ./triggerx.sh status${NC} (Check node status)"
    echo -e "   ${GREEN}cd ~/triggerx && ./triggerx.sh stop${NC} (Stop node)"
    echo -e "   ${GREEN}cd ~/triggerx && ./triggerx.sh start${NC} (Start node)"
    echo -e "   ${GREEN}cd ~/triggerx && ./triggerx.sh restart${NC} (Restart node)"
    echo ""
    echo -e "${BLUE}📝 Registration Documentation:${NC}"
    echo -e "   ${GREEN}https://triggerx.gitbook.io/triggerx-docs/join-as-keeper${NC}"
    echo -e "   ${GREEN}https://docs.othentic.xyz/main/avs-framework/othentic-cli/private-key-management${NC}"
    echo ""
    read -p "Press Enter to continue..."
}

# Main menu
display_main_menu() {
    while true; do
        display_banner
        echo -e "${BLUE}Main Menu:${NC}"
        echo -e "  ${GREEN}1.${NC} Install Dependencies"
        echo -e "  ${GREEN}2.${NC} Setup TriggerX Node"
        echo -e "  ${GREEN}3.${NC} Configure .env File and Generate Peer ID"
        echo -e "  ${GREEN}4.${NC} Start TriggerX Services"
        echo -e "  ${GREEN}5.${NC} Register TriggerX Node"
        echo -e "  ${GREEN}6.${NC} Show Node Status"
        echo -e "  ${GREEN}7.${NC} Help"
        echo -e "  ${GREEN}0.${NC} Exit"
        echo ""
        read -p "$(echo -e "${BLUE}Please select an option:${NC} ")" option
        
        case $option in
            1)
                install_dependencies
                read -p "Press Enter to continue..."
                ;;
            2)
                setup_triggerx_repo
                read -p "Press Enter to continue..."
                ;;
            3)
                setup_env_file
                read -p "Press Enter to continue..."
                ;;
            4)
                start_triggerx_services
                read -p "Press Enter to continue..."
                ;;
            5)
                register_triggerx
                ;;
            6)
                show_node_status
                ;;
            7)
                show_help
                ;;
            0)
                echo -e "${GREEN}Thank you for using TriggerX Keeper Menu Installer!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option. Please try again.${NC}"
                sleep 1
                ;;
        esac
    done
}

# Main function to start the menu
main() {
    display_main_menu
}

# Run the script
main
