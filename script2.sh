#!/usr/bin/env bash
# Script 2 – run as user 'asimas'
set -euo pipefail

# 1. Install the OpenSSH client tools if needed
sudo pacman -S --noconfirm --needed openssh

# 2. Generate a new Ed25519 keypair
ssh-keygen -t ed25519 -C "austin@simas.io"

# 3. Start the ssh-agent and add your key
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# 4. Show your public key for GitHub and wait for you to add it
echo
echo "==> Copy the following public key into GitHub → Settings → SSH and GPG keys:"
cat ~/.ssh/id_ed25519.pub
echo
read -rp "Press Enter after you’ve added the key to GitHub…"

# 5. Clone your bootstrap repo and run its installer
git clone git@github.com:ajsimas/arch-bootstrap.git
cd arch-bootstrap
sudo ./bootstrap.sh


