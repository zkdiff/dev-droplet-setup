#!/bin/bash
set -euo pipefail

# ============================================
# Droplet Bootstrap Script
# ============================================
# Quickly configure a fresh Ubuntu droplet for development
# Usage: curl -fsSL <url-to-this-script> | bash
# Or: bash bootstrap.sh

SCRIPT_VERSION="1.0.1"
LOG_FILE="/var/log/droplet-bootstrap.log"

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

# Install zsh
log "Installing zsh..."
wait_for_apt
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq zsh


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

# Easier prefix
set -g prefix C-a
unbind C-b
bind C-a send-prefix

# Easy config reload
bind r source-file ~/.tmux.conf \; display "Config reloaded"

# Split panes with | and -
bind \\ split-window -h
bind - split-window -v

# Status bar
set -g status-bg colour235
set -g status-fg colour136
set -g status-left-length 20
set -g status-right "%H:%M %d-%b-%y"
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
log "  - zsh"
log "  - tmux, vim, neovim"
log "  - build tools + utilities"
log ""
log "Next steps:"
log "  1. Log out and log back in (or run: exec zsh)"
log "  2. Configure git: git config --global user.name 'zkdiff'"
log "  3. Configure git: git config --global user.email '37495954+zkdiff@users.noreply.github.com'"
log ""
log "Full log available at: $LOG_FILE"
