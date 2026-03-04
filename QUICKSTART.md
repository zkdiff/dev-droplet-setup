# Quick Start

## Option 1: Existing Droplet (Bootstrap)

```bash
curl -fsSL https://raw.githubusercontent.com/zkdiff/dev-droplet-setup/main/bootstrap.sh | bash && exec zsh
```

## Option 2: New Droplet (Cloud-Init)

1. In DigitalOcean: Create > Droplets
2. Select Ubuntu 24.04
3. Open Advanced Options > User data
4. Paste contents of `cloud-init.yaml`
5. Create droplet and wait 2-3 minutes
6. SSH in: `ssh root@<ip>`

## Option 3: Automated via CLI

```bash
# One-time setup
curl -sL https://github.com/digitalocean/doctl/releases/download/v1.104.0/doctl-1.104.0-linux-amd64.tar.gz | tar -xzv
sudo mv doctl /usr/local/bin
doctl auth init

# Set SSH key ID for this shell session
doctl compute ssh-key list
export SSH_KEY_ID="<your-ssh-key-id>"

# Common commands
./droplet-manager.sh create
./droplet-manager.sh create --size s-2vcpu-2gb
./droplet-manager.sh create --region sfo3
./droplet-manager.sh create --size s-2vcpu-2gb --region sfo3
./droplet-manager.sh list
./droplet-manager.sh ssh <name>
./droplet-manager.sh destroy <name>
```

## After Provisioning

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
gh auth login
```

## Optional: Configure Docker registry credentials

If you need private pulls from DigitalOcean Container Registry, pass env vars before bootstrap:

```bash
DOCR_REGISTRY_USER="<email>" DOCR_REGISTRY_TOKEN="<dop-token>" bash bootstrap.sh
```

Then test a pull:

```bash
docker pull --platform linux/amd64 registry.digitalocean.com/narmada-dev-images/local-mssql:latest
```
