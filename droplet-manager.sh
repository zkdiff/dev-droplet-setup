#!/bin/bash
# ============================================
# DigitalOcean Droplet Manager
# ============================================
# Requires: doctl (DigitalOcean CLI)
# Install: https://docs.digitalocean.com/reference/doctl/how-to/install/

set -euo pipefail

# Get the directory of this script to reliably resolve relative paths like cloud-init.yaml
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration - edit defaults or override with environment variables
DROPLET_NAME="dam-dev"
DROPLET_SIZE="${DROPLET_SIZE:-c2-8vcpu-16gb-intel}"
DROPLET_REGION="${DROPLET_REGION:-sfo3}"
CLOUD_INIT_FILE="${CLOUD_INIT_FILE:-$SCRIPT_DIR/cloud-init.yaml}"

# Dynamically fetch all SSH Key IDs to ensure access
SSH_KEY_IDS=$(doctl compute ssh-key list --format ID --no-header | paste -sd "," -)

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
    local droplet_size="${1:-$DROPLET_SIZE}"
    local droplet_region="${2:-$DROPLET_REGION}"
    local rendered_cloud_init=""
    local docr_user=""
    local docr_token=""

    echo -e "${BLUE}Creating new droplet: ${DROPLET_NAME} (${droplet_size}, ${droplet_region})${NC}"

    local doctl_args=(
        compute droplet create "$DROPLET_NAME"
        --image ubuntu-24-04-x64
        --size "$droplet_size"
        --region "$droplet_region"
        --enable-monitoring
        --wait
        --format ID,Name,PublicIPv4,Status
    )

    if [ -f "$CLOUD_INIT_FILE" ]; then
        doctl_args+=(--user-data-file "$CLOUD_INIT_FILE")
        echo -e "${GREEN}Using cloud-init from: $CLOUD_INIT_FILE${NC}"
    fi

    if [ -n "$SSH_KEY_IDS" ]; then
        doctl_args+=(--ssh-keys "$SSH_KEY_IDS")
    fi

    doctl "${doctl_args[@]}"

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

        if [ -f "$CLOUD_INIT_FILE" ]; then
            echo -e "${BLUE}Waiting for cloud-init to complete (this may take a few minutes)...${NC}"

            # Wait for SSH to be ready
            echo -e "${YELLOW}Waiting for SSH access...${NC}"
            while ! ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -q root@"$ip" exit &>/dev/null; do
                sleep 5
            done

            echo -e "${YELLOW}SSH ready. Streaming cloud-init logs...${NC}"

            # Start streaming the log in the background locally
            ssh -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@"$ip" 'tail -n +1 -f /var/log/cloud-init-output.log 2>/dev/null' &
            TAIL_PID=$!

            # Wait for cloud-init to finish
            ssh -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@"$ip" 'cloud-init status --wait >/dev/null 2>&1' || true

            # Kill the tail process once provisioning is complete
            kill $TAIL_PID 2>/dev/null || true
            wait $TAIL_PID 2>/dev/null || true

            echo -e "${GREEN}Provisioning complete! You can now SSH into the droplet.${NC}"
        else
            echo -e "${YELLOW}If not using cloud-init, perform setup manually.${NC}"
        fi
    fi
}

# List all droplets
list_droplets() {
    echo -e "${BLUE}Your droplets:${NC}"
    doctl compute droplet list --format ID,Name,PublicIPv4,Status,Region,Memory,VCPUs,Disk
}

# Destroy a droplet
destroy_droplet() {
    local identifier="${1:-$DROPLET_NAME}"

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
    local target="${1:-$DROPLET_NAME}"

    doctl compute droplet list --format Name,PublicIPv4 --no-header | awk -v name="$target" '$1 == name {print $2; exit}'
}

ssh_droplet() {
    local target="${1:-$DROPLET_NAME}"
    local ip
    local forwarded_token="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
    ip="$(get_ip "$target")" || return 1

    [[ -z "$ip" ]] && { echo -e "${RED}Error: Could not find IP for droplet: $target${NC}"; return 1; }

    # Forward GitHub token to the droplet via SendEnv
    if [[ -z "$forwarded_token" ]]; then
        if command -v gh &>/dev/null; then
            forwarded_token="$(gh auth token 2>/dev/null)" || true
        fi
    fi
    if [[ -n "$forwarded_token" ]]; then
        echo -e "${GREEN}Forwarding GH_TOKEN/GITHUB_TOKEN to droplet${NC}"
    else
        echo -e "${YELLOW}Warning: GitHub token not available (install gh CLI or export GH_TOKEN/GITHUB_TOKEN)${NC}"
    fi



    local forwarded_do_token=""
    if command -v doctl &>/dev/null; then
        forwarded_do_token="$(doctl auth list --format Token --no-header 2>/dev/null | head -n 1)" || true
    fi
    if [[ -n "$forwarded_do_token" ]]; then
        echo -e "${GREEN}Forwarding DO_TOKEN (DigitalOcean Auth) to droplet${NC}"
    fi

    echo -e "${BLUE}Connecting to $target ($ip) via ssh config...${NC}"
    if declare -p ssh_args &>/dev/null && [[ ${#ssh_args[@]} -gt 0 ]]; then
        env TERM=xterm-256color GITHUB_TOKEN="$forwarded_token" GH_TOKEN="$forwarded_token" DO_TOKEN="$forwarded_do_token" ssh -o SendEnv=GITHUB_TOKEN,GH_TOKEN,DO_TOKEN -o HostName="$ip" "$target" "${ssh_args[@]}"
    else
        env TERM=xterm-256color GITHUB_TOKEN="$forwarded_token" GH_TOKEN="$forwarded_token" DO_TOKEN="$forwarded_do_token" ssh -o SendEnv=GITHUB_TOKEN,GH_TOKEN,DO_TOKEN -o HostName="$ip" "$target"
    fi
}

# Show usage
usage() {
    echo -e "${BLUE}DigitalOcean Droplet Manager${NC}"
    cat << EOF
Usage: $0 <command> [options]

Commands:
  create [--size <slug>] [--region <slug>] Create a new droplet with optional cloud-init
  list                List all your droplets
  destroy <id>        Destroy a droplet by ID or name
  ip <name>           Get IP address of a droplet
  ssh <name>          SSH into a droplet by name
  help                Show this help message

Configuration (edit script or override with env vars):
  DROPLET_NAME:    $DROPLET_NAME
  DROPLET_SIZE:    $DROPLET_SIZE
  DROPLET_REGION:  $DROPLET_REGION
  CLOUD_INIT_FILE: $CLOUD_INIT_FILE

Examples:
  $0 create
  $0 create --size s-2vcpu-2gb
  $0 create --region sfo3
  $0 create --size s-2vcpu-2gb --region sfo3
  $0 list
  $0 ssh dev-20260121-143022
  $0 destroy dev-20260121-143022
  $0 ip dev-20260121-143022

Setup:
  1. Install doctl: https://docs.digitalocean.com/reference/doctl/how-to/install/
  2. Authenticate: doctl auth init
  3. Note: SSH keys are now fetched automatically and applied.
EOF
}

# Main
main() {
    case "${1:-help}" in
        create)
            check_doctl
            shift

            local create_size=""
            local create_region=""
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --size|-s)
                        if [[ $# -lt 2 || "$2" == -* ]]; then
                            echo -e "${RED}Error: --size requires a machine size slug${NC}"
                            exit 1
                        fi
                        create_size="$2"
                        shift 2
                        ;;
                    --size=*)
                        create_size="${1#*=}"
                        if [[ -z "$create_size" ]]; then
                            echo -e "${RED}Error: --size requires a machine size slug${NC}"
                            exit 1
                        fi
                        shift
                        ;;
                    --region|-r)
                        if [[ $# -lt 2 || "$2" == -* ]]; then
                            echo -e "${RED}Error: --region requires a region slug${NC}"
                            exit 1
                        fi
                        create_region="$2"
                        shift 2
                        ;;
                    --region=*)
                        create_region="${1#*=}"
                        if [[ -z "$create_region" ]]; then
                            echo -e "${RED}Error: --region requires a region slug${NC}"
                            exit 1
                        fi
                        shift
                        ;;
                    *)
                        echo -e "${RED}Unknown option for create: $1${NC}"
                        echo "Use: $0 create [--size <slug>] [--region <slug>]"
                        exit 1
                        ;;
                esac
            done

            create_droplet "$create_size" "$create_region"
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
