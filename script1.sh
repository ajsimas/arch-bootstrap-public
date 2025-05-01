#!/usr/bin/env bash
# Script 1 – run as root
set -euo pipefail

# 1. (Optional but recommended) Update package database and system
pacman -Syu --noconfirm

# 2. Install sudo and git if not already present
pacman -S --noconfirm --needed sudo git

# 3. Enable passwordless sudo for wheel group
cat > /etc/sudoers.d/wheel << 'EOF'
%wheel ALL=(ALL) NOPASSWD: ALL
EOF
chmod 0440 /etc/sudoers.d/wheel

# 4. Create the user 'asimas', add to wheel group, set Bash shell
useradd -m -G wheel -s /bin/bash asimas

# 5. Prompt to set the new user's password
echo "Please enter and confirm a password for 'asimas':"
passwd asimas

echo "User 'asimas' created. You can now exit root and log in as 'asimas'."

