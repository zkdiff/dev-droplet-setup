# Quick Start Guide

## Option 1: Bootstrap This Droplet (You're Here Now)

Run this command on your current droplet:

```bash
cd /root && bash bootstrap.sh
```

Then reload your shell:
```bash
exec zsh
```

## Option 2: New Droplet with Cloud-Init

1. Go to DigitalOcean dashboard
2. Create > Droplets
3. Select Ubuntu 24.04
4. Advanced Options > User data
5. Paste contents of `/root/cloud-init.yaml`
6. Create droplet
7. Wait 2-3 minutes
8. SSH in: `ssh root@<ip>`

## Option 3: Automated with CLI

```bash
# One-time setup
curl -sL https://github.com/digitalocean/doctl/releases/download/v1.104.0/doctl-1.104.0-linux-amd64.tar.gz | tar -xzv
sudo mv doctl /usr/local/bin
doctl auth init

# Get SSH key ID and update droplet-manager.sh
doctl compute ssh-key list

# Create droplets
./droplet-manager.sh create
./droplet-manager.sh list
./droplet-manager.sh ssh <name>
./droplet-manager.sh destroy <name>
```

## What You Get

- Docker + Docker Compose
- Node.js (nvm) + npm
- .NET SDK 8.0
- Git + GitHub CLI (gh)
- zsh + oh-my-zsh
- tmux, vim, neovim
- Build tools + utilities

## Post-Install

```bash
# Configure git
git config --global user.name "Your Name"
git config --global user.email "you@example.com"

# Authenticate GitHub (optional)
gh auth login

# Verify installations
docker --version
node --version
dotnet --version
git --version
```

## Useful Aliases

- `ll` - detailed list
- `dc` - docker-compose
- `dps` - docker ps
- `gs` - git status
- `gl` - git log (graph)

## Next Steps

1. Start working: `cd ~/projects`
2. Clone a repo: `git clone <url>`
3. Start developing!
4. When done: destroy the droplet to save money

## Files

- `bootstrap.sh` - Manual provisioning script
- `cloud-init.yaml` - Automatic provisioning config
- `droplet-manager.sh` - Droplet management CLI
- `README.md` - Full documentation
- `QUICKSTART.md` - This file

## Need Help?

See `README.md` for full documentation and troubleshooting.
