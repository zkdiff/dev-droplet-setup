#!/bin/bash
# ============================================
# DigitalOcean Droplet Manager
# ============================================
# Requires: doctl (DigitalOcean CLI)
# Install: https://docs.digitalocean.com/reference/doctl/how-to/install/

set -euo pipefail

# Configuration - edit defaults or override with environment variables
DROPLET_NAME="${DROPLET_NAME:-dev-$(date +%Y%m%d-%H%M%S)}"
DROPLET_REGION="${DROPLET_REGION:-sfo3}"  # Change to your preferred region
DROPLET_SIZE="${DROPLET_SIZE:-s-2vcpu-4gb}"  # Change to your preferred size
DROPLET_IMAGE="${DROPLET_IMAGE:-ubuntu-24-04-x64}"
SSH_KEY_ID="${SSH_KEY_ID:-}"  # Add your SSH key ID (get with: doctl compute ssh-key list)
CLOUD_INIT_FILE="${CLOUD_INIT_FILE:-cloud-init.yaml}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if doctl is installed
check_doctl() {
    if ! command -v doctl &> /dev/null; then
        echo -e "${RED}Error: doctl is not installed${NC}"
        echo "Install it from: https://docs.digitalocean.com/reference/doctl/how-to/install/"
        exit 1
    fi
    
    # Check if authenticated
    if ! doctl account get &> /dev/null; then
        echo -e "${RED}Error: doctl is not authenticated${NC}"
        echo "Run: doctl auth init"
        exit 1
    fi
}

# Create a new droplet
create_droplet() {
    echo -e "${BLUE}Creating new droplet: ${DROPLET_NAME}${NC}"
    
    local user_data_arg=()
    if [ -f "$CLOUD_INIT_FILE" ]; then
        user_data_arg=(--user-data-file "$CLOUD_INIT_FILE")
        echo -e "${GREEN}Using cloud-init from: $CLOUD_INIT_FILE${NC}"
    fi
    
    local ssh_keys_arg=()
    if [ -n "$SSH_KEY_ID" ]; then
        ssh_keys_arg=(--ssh-keys "$SSH_KEY_ID")
    fi
    
    doctl compute droplet create "$DROPLET_NAME" \
        --region "$DROPLET_REGION" \
        --size "$DROPLET_SIZE" \
        --image "$DROPLET_IMAGE" \
        "${ssh_keys_arg[@]}" \
        "${user_data_arg[@]}" \
        --wait \
        --format ID,Name,PublicIPv4,Status
    
    echo ""
    echo -e "${GREEN}Droplet created successfully!${NC}"
    echo ""
    
    # Get the IP address
    local ip
    ip=$(doctl compute droplet list --format Name,PublicIPv4 --no-header | awk -v name="$DROPLET_NAME" '$1 == name {print $2; exit}')
    
    if [ -n "$ip" ]; then
        echo -e "${YELLOW}Connection info:${NC}"
        echo "  IP Address: $ip"
        echo "  SSH: ssh root@$ip"
        echo ""
        echo -e "${YELLOW}If using cloud-init, wait 2-3 minutes for provisioning to complete${NC}"
        echo "Check status: ssh root@$ip 'tail -f /var/log/cloud-init-output.log'"
        echo ""
        echo -e "${YELLOW}If not using cloud-init, bootstrap manually:${NC}"
        echo "  ssh root@$ip 'bash -s' < bootstrap.sh"
    fi
}

# List all droplets
list_droplets() {
    echo -e "${BLUE}Your droplets:${NC}"
    doctl compute droplet list --format ID,Name,PublicIPv4,Status,Region,Size,Created
}

# Destroy a droplet
destroy_droplet() {
    if [ -z "${1:-}" ]; then
        echo -e "${RED}Error: Please provide droplet ID or name${NC}"
        echo "Usage: $0 destroy <droplet-id-or-name>"
        exit 1
    fi
    
    local identifier="$1"
    
    echo -e "${YELLOW}Are you sure you want to destroy droplet: $identifier? (y/N)${NC}"
    read -r response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        doctl compute droplet delete "$identifier" --force
        echo -e "${GREEN}Droplet destroyed${NC}"
    else
        echo -e "${YELLOW}Cancelled${NC}"
    fi
}

# Get droplet IP
get_ip() {
    if [ -z "${1:-}" ]; then
        echo -e "${RED}Error: Please provide droplet name${NC}"
        echo "Usage: $0 ip <droplet-name>"
        exit 1
    fi
    
    doctl compute droplet list --format Name,PublicIPv4 --no-header | awk -v name="$1" '$1 == name {print $2; exit}'
}

# SSH into a droplet
ssh_droplet() {
    if [ -z "${1:-}" ]; then
        echo -e "${RED}Error: Please provide droplet name${NC}"
        echo "Usage: $0 ssh <droplet-name>"
        exit 1
    fi
    
    local ip=$(get_ip "$1")
    
    if [ -z "$ip" ]; then
        echo -e "${RED}Error: Could not find IP for droplet: $1${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}Connecting to $1 ($ip)...${NC}"
    ssh root@"$ip"
}

# Show usage
usage() {
    echo -e "${BLUE}DigitalOcean Droplet Manager${NC}"
    cat << EOF
Usage: $0 <command> [options]

Commands:
  create              Create a new droplet with optional cloud-init
  list                List all your droplets
  destroy <id>        Destroy a droplet by ID or name
  ip <name>           Get IP address of a droplet
  ssh <name>          SSH into a droplet by name
  help                Show this help message

Configuration (edit script or override with env vars):
  DROPLET_NAME:    $DROPLET_NAME
  DROPLET_REGION:  $DROPLET_REGION
  DROPLET_SIZE:    $DROPLET_SIZE
  DROPLET_IMAGE:   $DROPLET_IMAGE
  SSH_KEY_ID:      ${SSH_KEY_ID:-"Not set"}

Examples:
  $0 create
  $0 list
  $0 ssh dev-20260121-143022
  $0 destroy dev-20260121-143022
  $0 ip dev-20260121-143022

Setup:
  1. Install doctl: https://docs.digitalocean.com/reference/doctl/how-to/install/
  2. Authenticate: doctl auth init
  3. Get SSH key ID: doctl compute ssh-key list
  4. Set SSH_KEY_ID as an env var or edit script defaults
EOF
}

# Main
main() {
    case "${1:-help}" in
        create)
            check_doctl
            create_droplet
            ;;
        list)
            check_doctl
            list_droplets
            ;;
        destroy)
            check_doctl
            destroy_droplet "${2:-}"
            ;;
        ip)
            check_doctl
            get_ip "${2:-}"
            ;;
        ssh)
            check_doctl
            ssh_droplet "${2:-}"
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            echo -e "${RED}Unknown command: ${1:-}${NC}"
            echo ""
            usage
            exit 1
            ;;
    esac
}

main "$@"
