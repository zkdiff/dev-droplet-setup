#!/bin/bash
set -euo pipefail

# ============================================
# Droplet Bootstrap Script
# ============================================
# Quickly configure a fresh Ubuntu droplet for development
# Usage: curl -fsSL <url-to-this-script> | bash
# Or: bash bootstrap.sh

SCRIPT_VERSION="1.0.0"
LOG_FILE="/var/log/droplet-bootstrap.log"

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

# Update system
log "Updating system packages..."
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq

# Install essential packages
log "Installing essential packages..."
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

# Install zsh and oh-my-zsh
log "Installing zsh and oh-my-zsh..."
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq zsh

# Install oh-my-zsh for root
if [ ! -d "/root/.oh-my-zsh" ]; then
    log "Installing oh-my-zsh for root..."
    RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || warn "oh-my-zsh installation had issues"
fi

# Change default shell to zsh
chsh -s "$(which zsh)" root

# Install Docker
log "Installing Docker..."
if ! command -v docker &> /dev/null; then
    # Add Docker's official GPG key
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    # Add Docker repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

    # Start and enable Docker
    systemctl enable docker
    systemctl start docker
    log "Docker installed successfully"
else
    log "Docker already installed"
fi

# Install Node.js (using nvm for flexibility)
log "Installing Node.js via nvm..."
if [ ! -d "/root/.nvm" ]; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    export NVM_DIR="/root/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    nvm install --lts
    nvm use --lts
    nvm alias default node
    log "Node.js installed via nvm"
else
    log "nvm already installed"
fi

# Install .NET SDK
log "Installing .NET SDK..."
if ! command -v dotnet &> /dev/null; then
    wget https://dot.net/v1/dotnet-install.sh -O /tmp/dotnet-install.sh
    chmod +x /tmp/dotnet-install.sh
    /tmp/dotnet-install.sh --channel 8.0 --install-dir /usr/share/dotnet
    ln -sf /usr/share/dotnet/dotnet /usr/local/bin/dotnet
    log ".NET SDK installed"
else
    log ".NET SDK already installed"
fi

# Install GitHub CLI
log "Installing GitHub CLI..."
if ! command -v gh &> /dev/null; then
    mkdir -p -m 755 /etc/apt/keyrings
    wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
    chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq gh
    log "GitHub CLI installed"
else
    log "GitHub CLI already installed"
fi

# Configure git defaults
log "Configuring git defaults..."
git config --global init.defaultBranch main
git config --global pull.rebase false
git config --global core.editor vim

# Create a basic .zshrc if it doesn't exist
log "Configuring zsh..."
cat > /root/.zshrc << 'EOF'
# Path to oh-my-zsh installation
export ZSH="$HOME/.oh-my-zsh"

# Theme
ZSH_THEME="robbyrussell"

# Plugins
plugins=(git docker docker-compose npm node)

source $ZSH/oh-my-zsh.sh

# NVM configuration
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias dc='docker-compose'
alias dps='docker ps'
alias dcu='docker-compose up -d'
alias dcd='docker-compose down'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph --decorate'

# Custom prompt with timestamp
PROMPT='%{$fg[cyan]%}[%*] %{$fg[green]%}%n@%m%{$reset_color%}:%{$fg[blue]%}%~%{$reset_color%}$(git_prompt_info) %# '

# Environment variables
export EDITOR=vim
export VISUAL=vim
export DOTNET_ROOT=/usr/share/dotnet
export PATH=$PATH:$DOTNET_ROOT

# History settings
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE

# Auto-completion
autoload -Uz compinit
compinit

echo "🚀 Droplet ready for development!"
echo "Installed: Docker, Node.js, .NET, Git, GitHub CLI"
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
bind r source-file ~/.tmux.conf \; display "Config reloaded!"

# Split panes with | and -
bind | split-window -h
bind - split-window -v

# Status bar
set -g status-bg colour235
set -g status-fg colour136
set -g status-left-length 20
set -g status-right "%H:%M %d-%b-%y"
EOF

# Create a useful vim configuration
log "Configuring vim..."
cat > /root/.vimrc << 'EOF'
" Basic settings
syntax on
set number
set relativenumber
set tabstop=4
set shiftwidth=4
set expandtab
set smartindent
set autoindent
set showcmd
set wildmenu
set incsearch
set hlsearch
set ignorecase
set smartcase
set backspace=indent,eol,start
set ruler
set laststatus=2
set encoding=utf-8

" Color scheme
colorscheme desert

" Disable swap files
set noswapfile
set nobackup
set nowritebackup

" Highlight trailing whitespace
highlight ExtraWhitespace ctermbg=red guibg=red
match ExtraWhitespace /\s\+$/
EOF

# Create a project directory
log "Creating project directories..."
mkdir -p /root/projects
mkdir -p /root/scripts

# Set timezone (optional - adjust as needed)
log "Setting timezone to UTC..."
timedatectl set-timezone UTC

# Enable automatic security updates
log "Configuring automatic security updates..."
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades

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
log "  - Docker & Docker Compose"
log "  - Node.js (via nvm)"
log "  - .NET SDK 8.0"
log "  - Git & GitHub CLI"
log "  - zsh with oh-my-zsh"
log "  - tmux, vim, neovim"
log "  - Build tools & utilities"
log ""
log "Next steps:"
log "  1. Log out and log back in (or run: exec zsh)"
log "  2. Configure git: git config --global user.name 'Your Name'"
log "  3. Configure git: git config --global user.email 'you@example.com'"
log "  4. Authenticate GitHub CLI: gh auth login"
log ""
log "Your projects directory: /root/projects"
log "Full log available at: $LOG_FILE"
