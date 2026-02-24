# DigitalOcean Droplet Provisioning System

Quickly create, configure, and destroy DigitalOcean droplets for development work.

## Quick Start

For setup instructions, use `QUICKSTART.md`.
This document covers tooling, configuration, customization, and troubleshooting.

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

## Useful Aliases

The following aliases are pre-configured in `.zshrc`:

```bash
ll         # ls -alF
dc         # docker compose
dps        # docker ps
dcu        # docker compose up -d
dcd        # docker compose down
gs         # git status
ga         # git add
gc         # git commit
gp         # git push
gl         # git log --oneline --graph
```

## Repository Structure

```text
.
├── bootstrap.sh
├── cloud-init.yaml
├── droplet-manager.sh
├── QUICKSTART.md
└── README.md
```

On provisioned droplets, `bootstrap.sh` creates `/root/projects` and `/root/scripts`.

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

`bootstrap.sh` is linear; re-run the full script instead of sourcing sections:
```bash
# If cloud-init already downloaded it:
bash /root/bootstrap.sh

# Or fetch and run the latest copy:
curl -fsSL https://raw.githubusercontent.com/zkdiff/dev-droplet-setup/main/bootstrap.sh -o /root/bootstrap.sh && bash /root/bootstrap.sh
```

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

1. **Configure firewall** via DigitalOcean or ufw
   ```bash
   ufw allow 22/tcp
   ufw allow 80/tcp
   ufw allow 443/tcp
   ufw enable
   ```

2. **Use non-root user** for production workloads
   ```bash
   adduser developer
   usermod -aG sudo,docker developer
   ```