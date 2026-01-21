# DigitalOcean Droplet Provisioning System

Quickly create, configure, and destroy DigitalOcean droplets for development work.

## Quick Start

### Method 1: Bootstrap Script (Existing Droplet)

If you already have a fresh droplet running, SSH into it and run:

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/bootstrap.sh | bash
```

Or if you have the script locally:

```bash
bash bootstrap.sh
```

This will install and configure everything automatically.

### Method 2: Cloud-Init (New Droplet)

When creating a new droplet via DigitalOcean's web interface or API:

1. Navigate to Create > Droplets
2. Select Ubuntu 24.04
3. Scroll to "Advanced Options"
4. Paste the contents of `cloud-init.yaml` into the "User data" field
5. Create the droplet

The droplet will be fully provisioned on first boot (takes 2-3 minutes).

### Method 3: Automated Management Script

Use the included `droplet-manager.sh` script to create and manage droplets:

```bash
# Setup (one-time)
# 1. Install doctl
curl -sL https://github.com/digitalocean/doctl/releases/download/v1.104.0/doctl-1.104.0-linux-amd64.tar.gz | tar -xzv
sudo mv doctl /usr/local/bin

# 2. Authenticate
doctl auth init

# 3. Get your SSH key ID
doctl compute ssh-key list

# 4. Edit droplet-manager.sh and update SSH_KEY_ID

# Usage
./droplet-manager.sh create          # Create new droplet
./droplet-manager.sh list            # List all droplets
./droplet-manager.sh ssh <name>      # SSH into droplet
./droplet-manager.sh destroy <name>  # Destroy droplet
```

## What Gets Installed

### Development Tools
- **Docker** + Docker Compose - Container runtime
- **Node.js** (via nvm) - Latest LTS version
- **.NET SDK 8.0** - .NET development
- **Git** + GitHub CLI - Version control
- **Build tools** - gcc, g++, make

### Terminal Tools
- **zsh** with oh-my-zsh - Enhanced shell
- **tmux** - Terminal multiplexer
- **vim** + neovim - Text editors
- **htop** - Process monitor
- **ripgrep** - Fast search
- **fd** - Fast find alternative
- **bat** - Better cat
- **jq** - JSON processor
- **tree** - Directory visualization
- **ncdu** - Disk usage analyzer

### Configuration
- Pre-configured `.zshrc` with useful aliases
- Pre-configured `.tmux.conf` with sensible defaults
- Pre-configured `.vimrc` for basic editing
- Git defaults (main branch, vim editor)
- Automatic security updates enabled

## Post-Installation Steps

After provisioning, you'll need to:

1. **Configure Git Identity**
   ```bash
   git config --global user.name "Your Name"
   git config --global user.email "your.email@example.com"
   ```

2. **Authenticate GitHub CLI** (optional)
   ```bash
   gh auth login
   ```

3. **Load zsh** (if using bootstrap method)
   ```bash
   exec zsh
   ```

## Useful Aliases

The following aliases are pre-configured in `.zshrc`:

```bash
ll         # ls -alF
dc         # docker-compose
dps        # docker ps
dcu        # docker-compose up -d
dcd        # docker-compose down
gs         # git status
ga         # git add
gc         # git commit
gp         # git push
gl         # git log --oneline --graph
```

## Directory Structure

```
/root
├── projects/          # Your project directory
├── scripts/           # Custom scripts
├── bootstrap.sh       # Bootstrap script
├── cloud-init.yaml    # Cloud-init configuration
└── droplet-manager.sh # Droplet management script
```

## Customization

### Modifying Bootstrap Script

Edit `bootstrap.sh` to add/remove packages or configuration:

```bash
vim bootstrap.sh
```

Key sections:
- Line 40-65: Package installation
- Line 70-85: Docker installation
- Line 90-105: Node.js installation
- Line 110-125: .NET installation
- Line 150-200: Configuration files

### Modifying Cloud-Init

Edit `cloud-init.yaml` to customize first-boot behavior:

```bash
vim cloud-init.yaml
```

Key sections:
- `packages`: List of apt packages to install
- `write_files`: Configuration files to create
- `runcmd`: Commands to run on first boot

### Changing Default Settings

Edit `droplet-manager.sh` configuration:

```bash
vim droplet-manager.sh
```

Update these variables:
- `DROPLET_REGION`: Datacenter location (sfo3, nyc1, etc.)
- `DROPLET_SIZE`: Droplet size (s-2vcpu-4gb, s-4vcpu-8gb, etc.)
- `SSH_KEY_ID`: Your SSH key ID

## Workflows

### Quick Development Session

```bash
# Create a new droplet
./droplet-manager.sh create

# Wait 2-3 minutes for cloud-init
# SSH in
./droplet-manager.sh ssh dev-YYYYMMDD-HHMMSS

# Do your work...

# Destroy when done
./droplet-manager.sh destroy dev-YYYYMMDD-HHMMSS
```

### Multiple Droplets

```bash
# Create multiple droplets for different projects
# Edit droplet-manager.sh and change DROPLET_NAME before each create
DROPLET_NAME="web-project" ./droplet-manager.sh create
DROPLET_NAME="api-project" ./droplet-manager.sh create

# List all
./droplet-manager.sh list

# Work on specific project
./droplet-manager.sh ssh web-project
```

### Saving Custom Configuration

If you make custom changes to a droplet:

```bash
# On the droplet, create a backup of your configs
tar czf ~/my-dotfiles.tar.gz ~/.zshrc ~/.tmux.conf ~/.vimrc

# Download to your local machine
scp root@<droplet-ip>:~/my-dotfiles.tar.gz .

# Upload to new droplets
scp my-dotfiles.tar.gz root@<new-droplet-ip>:~/
ssh root@<new-droplet-ip> 'cd ~ && tar xzf my-dotfiles.tar.gz'
```

## Troubleshooting

### Cloud-init Not Running

Check cloud-init status:
```bash
ssh root@<ip> 'cloud-init status'
```

View cloud-init logs:
```bash
ssh root@<ip> 'tail -f /var/log/cloud-init-output.log'
```

### Bootstrap Script Fails

Check the log file:
```bash
cat /var/log/droplet-bootstrap.log
```

Re-run specific sections manually by sourcing the script and calling functions.

### Docker Not Starting

```bash
systemctl status docker
systemctl restart docker
```

### NVM Not Found

Restart your shell or source nvm:
```bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
```

## Cost Optimization

To minimize costs:

1. **Use smaller droplets** for light development
   - `s-1vcpu-1gb` for basic work
   - `s-2vcpu-2gb` for most development
   - Scale up only when needed

2. **Destroy droplets when not in use**
   ```bash
   ./droplet-manager.sh destroy <name>
   ```

3. **Use snapshots** for long-term storage
   ```bash
   doctl compute droplet-action snapshot <droplet-id> --snapshot-name my-dev-env
   ```

4. **Track your usage**
   ```bash
   doctl compute droplet list
   ```

## Security Recommendations

1. **Use SSH keys only** (no password authentication)
2. **Configure firewall** via DigitalOcean or ufw
   ```bash
   ufw allow 22/tcp
   ufw allow 80/tcp
   ufw allow 443/tcp
   ufw enable
   ```
3. **Keep system updated** (automatic updates are enabled)
4. **Use non-root user** for production workloads
   ```bash
   adduser developer
   usermod -aG sudo,docker developer
   ```

## Advanced: Creating a GitHub Repository

To make your bootstrap script accessible via URL:

1. Create a new GitHub repository
2. Add your files:
   ```bash
   git init
   git add bootstrap.sh cloud-init.yaml droplet-manager.sh README.md
   git commit -m "Initial droplet provisioning setup"
   git remote add origin git@github.com:YOUR_USERNAME/YOUR_REPO.git
   git push -u origin main
   ```

3. Use the raw GitHub URL in your bootstrap command:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/bootstrap.sh | bash
   ```

## Resources

- [DigitalOcean Documentation](https://docs.digitalocean.com/)
- [doctl CLI Reference](https://docs.digitalocean.com/reference/doctl/)
- [Cloud-init Documentation](https://cloudinit.readthedocs.io/)
- [Ubuntu Server Guide](https://ubuntu.com/server/docs)

## Support

For issues or improvements:
1. Check the troubleshooting section above
2. Review log files (`/var/log/droplet-bootstrap.log` or `/var/log/cloud-init-output.log`)
3. Test changes locally before deploying to production

---

Generated with Claude Code
