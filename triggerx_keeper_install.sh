#!/bin/bash

set -e

# === PROMPT USER ===
read -p "Enter ETH RPC (Holesky) endpoint (Alchemy/Infura/Zan.Top): " L1_RPC
read -p "Enter BASE RPC (Base Sepolia) endpoint: " L2_RPC

read -s -p "Enter your PRIVATE KEY (Use burner or 2nd Wallet, Don't use Main Wallet): " PRIVATE_KEY
echo
read -p "Enter your OPERATOR_ADDRESS (0x... same with your Address from your Private Key): " OPERATOR_ADDRESS

read -p "Enter Operator RPC port [default: 9005]: " OPERATOR_RPC_PORT
OPERATOR_RPC_PORT=${OPERATOR_RPC_PORT:-9005}

read -p "Enter Operator P2P port [default: 9006]: " OPERATOR_P2P_PORT
OPERATOR_P2P_PORT=${OPERATOR_P2P_PORT:-9006}

read -p "Enter Operator Metrics port [default: 9009]: " OPERATOR_METRICS_PORT
OPERATOR_METRICS_PORT=${OPERATOR_METRICS_PORT:-9009}

read -p "Enter Grafana port [default: 4000]: " GRAFANA_PORT
GRAFANA_PORT=${GRAFANA_PORT:-4000}

# === STATIC CONFIG ===
KEEPER_DIR="$HOME/triggerx"
REPO_URL="https://github.com/trigg3rX/triggerx-keeper-setup.git"
NODE_VERSION="22"
OTHENTIC_CLI_VERSION="1.10.0"
GOV_CONTRACT="0xE52De62Bf743493d3c4E1ac8db40f342FEb11fEa"

# === INSTALL DEPENDENCIES ===
sudo apt update && sudo apt install -y git curl docker.io docker-compose
curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | sudo -E bash -
sudo apt install -y nodejs

npm install -g @othentic/othentic-cli@$OTHENTIC_CLI_VERSION

# === CLONE REPO ===
git clone $REPO_URL $KEEPER_DIR
cd $KEEPER_DIR
cp .env.example .env

# === GET VPS IP & PEER_ID ===
PUBLIC_IPV4_ADDRESS=$(curl -s ifconfig.me)
PEER_ID=$(othentic-cli node get-id --node-type attester | grep -oE '12D3.*')

# === POPULATE .env ===
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

# === STARTUP ===
./triggerx.sh install && \
./triggerx.sh start && \
./triggerx.sh start-mon

# === GUIDE FOR REGISTRATION ===
echo ""
echo "✅ Environment configured and services started."
echo "Next steps:"
echo "1️⃣ Register Operator on EigenLayer:"
echo "   othentic-cli operator register-eigenlayer"
echo ""
echo "   When prompted, enter:"
echo "     - Private Key"
echo "     - Operator Name, Description, Website, Logo, Twitter"
echo "     - AVS Governance Address: $GOV_CONTRACT"
echo ""
echo "2️⃣ Deposit into strategy (e.g. stETH):"
echo "   othentic-cli operator deposit --staking-contract stETH --amount 0.001 --convert 0.002"
echo ""
echo "3️⃣ Register with TriggerX:"
echo "   othentic-cli operator register"
echo "   Use same PRIVATE_KEY and SIGNING_KEY (can be same on testnet)"
echo ""
echo "🌐 Grafana: http://$PUBLIC_IPV4_ADDRESS:$GRAFANA_PORT"
