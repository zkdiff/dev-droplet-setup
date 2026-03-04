#!/bin/bash
set -euo pipefail

# ============================================
# Droplet Bootstrap Script
# ============================================
# Quickly configure a fresh Ubuntu droplet for development
# Usage: curl -fsSL <url-to-this-script> | bash
# Or: bash bootstrap.sh

SCRIPT_VERSION="1.0.2"
LOG_FILE="/var/log/droplet-bootstrap.log"

DOCR_REGISTRY_HOST="registry.digitalocean.com"
DOCR_REGISTRY_USER="${DOCR_REGISTRY_USER:-zkdiff@gmail.com}"
DOCR_REGISTRY_TOKEN="${DOCR_REGISTRY_TOKEN:-}"

# Provide a reliable default for HOME so tools like git (via cloud-init) don't fail
export HOME=/root

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root"
fi

log "========================================"
log "Droplet Bootstrap Script v${SCRIPT_VERSION}"
log "========================================"

# Wait for background apt processes to finish
wait_for_apt() {
    log "Waiting for apt locks to be released..."
    while fuser /var/lib/dpkg/lock >/dev/null 2>&1 || fuser /var/lib/apt/lists/lock >/dev/null 2>&1 || fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
        sleep 5
    done
}

# Update system
log "Updating system packages..."
wait_for_apt
apt-get update -qq
wait_for_apt
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq

# Install essential packages
log "Installing essential packages..."
wait_for_apt
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    git \
    vim \
    neovim \
    tmux \
    curl \
    wget \
    htop \
    net-tools \
    build-essential \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    unzip \
    zip \
    jq \
    tree \
    ncdu \
    ripgrep \
    fd-find \
    bat

# Install Docker engine
log "Installing Docker engine..."
wait_for_apt
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq docker.io
systemctl enable --now docker

# Configure Docker auth for DigitalOcean registry pulls
configure_docr_registry_auth() {
    if [[ -z "${DOCR_REGISTRY_TOKEN}" ]]; then
        warn "DOCR_REGISTRY_TOKEN is empty; skipping Docker registry auth setup"
        return
    fi

    log "Configuring Docker auth for ${DOCR_REGISTRY_HOST}..."
    mkdir -p /root/.docker

    local auth
    local tmp_file
    auth="$(printf '%s:%s' "${DOCR_REGISTRY_USER}" "${DOCR_REGISTRY_TOKEN}" | base64 | tr -d '\n')"
    tmp_file="$(mktemp)"

    if [[ -f /root/.docker/config.json ]]; then
        if jq --arg host "${DOCR_REGISTRY_HOST}" --arg auth "${auth}" '.auths = (.auths // {}) | .auths[$host] = {auth: $auth}' /root/.docker/config.json >"${tmp_file}"; then
            mv "${tmp_file}" /root/.docker/config.json
        else
            warn "Existing Docker config was not valid JSON; replacing it"
            cat > /root/.docker/config.json <<EOF
{"auths":{"${DOCR_REGISTRY_HOST}":{"auth":"${auth}"}}}
EOF
            rm -f "${tmp_file}"
        fi
    else
        cat > /root/.docker/config.json <<EOF
{"auths":{"${DOCR_REGISTRY_HOST}":{"auth":"${auth}"}}}
EOF
        rm -f "${tmp_file}"
    fi

    chmod 600 /root/.docker/config.json
    log "Docker registry auth configured for ${DOCR_REGISTRY_HOST}"
}

configure_docr_registry_auth

# Install zsh
log "Installing zsh..."
wait_for_apt
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq zsh

(type -p wget >/dev/null || (sudo apt update && sudo apt install wget -y)) \
	&& sudo mkdir -p -m 755 /etc/apt/keyrings \
	&& out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
	&& cat $out | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
	&& sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
	&& sudo mkdir -p -m 755 /etc/apt/sources.list.d \
	&& echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
	&& sudo apt update \
	&& sudo apt install gh -y

# Change default shell to zsh
chsh -s "$(which zsh)" root

# Configure git defaults
log "Configuring git defaults..."
git config --global init.defaultBranch main
git config --global pull.rebase false
git config --global core.editor nvim


# Create a basic .zshrc
log "Configuring zsh..."
cat > /root/.zshrc << 'EOF'
# Custom Settings

# Aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph --decorate'
command -v fdfind >/dev/null 2>&1 && alias fd='fdfind'
command -v batcat >/dev/null 2>&1 && alias bat='batcat'

# Environment variables
export EDITOR=nvim
export VISUAL=nvim

# History settings (Zsh specific)
export HISTSIZE=10000
export SAVEHIST=10000
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE

# Auto-completion
autoload -Uz compinit && compinit

# Helpful welcome message on login
echo "🚀 Welcome to your development droplet!"
echo "Installed: Git, zsh, tmux, nvim"
EOF


# Create a basic .tmux.conf
log "Configuring tmux..."
cat > /root/.tmux.conf << 'EOF'
# Enable mouse support
set -g mouse on

# Improve colors
set -g default-terminal "screen-256color"

# Set scrollback buffer
set -g history-limit 10000

# Start window numbering at 1
set -g base-index 1
setw -g pane-base-index 1

# Prefix key
unbind C-b
set -g prefix Escape
bind Escape send-prefix

# Easy config reload
bind r source-file ~/.tmux.conf \; display "Config reloaded"

# Split panes with | and -
bind \\ split-window -h
bind - split-window -v

# Status bar
set -g status off
EOF

# Create a useful Neovim configuration
log "Configuring Neovim..."
mkdir -p /root/.config/nvim
cat > /root/.config/nvim/init.lua << 'EOF'
-- Basic Settings
vim.opt.number = true              -- Show line numbers
vim.opt.relativenumber = true      -- Show relative line numbers
vim.opt.tabstop = 4               -- Number of spaces tabs count for
vim.opt.shiftwidth = 4            -- Size of an indent
vim.opt.expandtab = true          -- Use spaces instead of tabs
vim.opt.smartindent = true        -- Insert indents automatically
vim.opt.autoindent = true         -- Copy indent from current line when starting new one
vim.opt.ignorecase = true         -- Ignore case when searching
vim.opt.smartcase = true          -- Override ignorecase if search pattern contains upper case characters
vim.opt.incsearch = true          -- Show search matches as you type
vim.opt.hlsearch = true           -- Highlight search results
vim.opt.termguicolors = true      -- True color support

-- Leader key
vim.g.mapleader = " "

-- Color scheme (default)
vim.cmd("colorscheme desert")

-- Highlight trailing whitespace
vim.cmd([[
  highlight ExtraWhitespace ctermbg=red guibg=red
  match ExtraWhitespace /\s\+$/
]])
EOF


# Configure sshd to accept token variables from client
log "Configuring sshd to accept GH and Docker registry token env vars..."
cat > /etc/ssh/sshd_config.d/99-github-token.conf << 'EOF'
AcceptEnv GITHUB_TOKEN GH_TOKEN DOCR_REGISTRY_USER DOCR_REGISTRY_TOKEN
EOF

if command -v systemctl >/dev/null 2>&1; then
    systemctl restart ssh || systemctl restart sshd
else
    service ssh restart || service sshd restart
fi

# Set timezone (optional - adjust as needed)
log "Setting timezone to PST..."
timedatectl set-timezone America/Los_Angeles

# Enable automatic security updates
log "Configuring automatic security updates..."
wait_for_apt
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq unattended-upgrades
DEBIAN_FRONTEND=noninteractive dpkg-reconfigure -f noninteractive unattended-upgrades

# Clean up
log "Cleaning up..."
apt-get autoremove -y -qq
apt-get clean

# Create a marker file to indicate bootstrap completed
echo "Bootstrap completed at $(date)" > /root/.bootstrap-complete

log "========================================"
log "Bootstrap completed successfully!"
log "========================================"
log ""
log "Summary of installed tools:"
log "  - git"
log "  - docker"
log "  - zsh"
log "  - tmux, vim, neovim"
log "  - build tools + utilities"
log "  - DOCR pull auth for ${DOCR_REGISTRY_HOST}"
log ""
log "Next steps:"
log "  1. Log out and log back in (or run: exec zsh)"
log "  2. Configure git: git config --global user.name 'zkdiff'"
log "  3. Configure git: git config --global user.email '37495954+zkdiff@users.noreply.github.com'"
log ""
log "Full log available at: $LOG_FILE"
