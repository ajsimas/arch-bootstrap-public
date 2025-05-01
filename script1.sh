#!/usr/bin/env bash
#
# arch-bootstrap.sh – Unified Arch Linux bootstrap (root + user phases)
#
# Usage:
#   As root (live-CD or installer environment): ./arch-bootstrap.sh
#
# What it does:
#   • Root-phase:
#     1. Full system update
#     2. Install sudo & git
#     3. Enable passwordless sudo for wheel
#     4. Create your normal user
#     → then re-executes itself as that user
#
#   • User-phase:
#     1. Install OpenSSH client
#     2. Generate Ed25519 key (if missing)
#     3. Start ssh-agent + add key
#     4. Display pubkey & pause for you to add it to GitHub
#     5. Clone your private repo & run its bootstrap.sh

set -euo pipefail
trap 'error "Unexpected error on line $LINENO."; exit 1' ERR
trap 'info "Interrupted."; exit 130' INT

# ——— Logging helpers ———
info () { printf "\033[1;34m[INFO]\033[0m  %s\n" "$*"; }
warn () { printf "\033[1;33m[WARN]\033[0m  %s\n" "$*"; }
error() { printf "\033[1;31m[ERROR]\033[0m %s\n" "$*" >&2; }

# ——— Configuration ———
BOOT_USER="asimas"
BOOT_USER_SHELL="/bin/bash"
SSH_KEY_EMAIL="austin@simas.io"
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
PRIVATE_REPO="git@github.com:ajsimas/arch-bootstrap.git"

# ——— Root-phase ———
if [[ $EUID -eq 0 && "${1:-}" != "--as-user" ]]; then
  info "== Root-phase starting =="

  info "1) Updating system…"
  pacman -Syu --noconfirm

  info "2) Installing sudo & git…"
  pacman -S --noconfirm --needed sudo git

  info "3) Enabling wheel passwordless sudo…"
  cat >/etc/sudoers.d/wheel << 'EOF'
%wheel ALL=(ALL) NOPASSWD: ALL
EOF
  chmod 0440 /etc/sudoers.d/wheel

  info "4) Creating user '$BOOT_USER'…"
  if id "$BOOT_USER" &>/dev/null; then
    warn "User '$BOOT_USER' already exists; skipping."
  else
    useradd -m -G wheel -s "$BOOT_USER_SHELL" "$BOOT_USER"
    info "Please set a password for '$BOOT_USER':"
    passwd "$BOOT_USER"
  fi

  info "Root-phase complete. Switching to '$BOOT_USER'…"
  exec runuser -u "$BOOT_USER" -- "$SCRIPT_PATH" --as-user
fi

# ——— User-phase ———
if [[ "${1:-}" == "--as-user" ]]; then
  [[ $EUID -eq 0 ]] && { error "User-phase must not run as root."; exit 1; }
  info "== User-phase starting as '$(whoami)' =="

  info "1) Installing OpenSSH client…"
  sudo pacman -S --noconfirm --needed openssh

  info "2) Generating SSH key (if needed)…"
  KEY="$HOME/.ssh/id_ed25519"
  if [[ -f $KEY ]]; then
    warn "Key already exists at $KEY; skipping."
  else
    ssh-keygen -t ed25519 -C "$SSH_KEY_EMAIL" -f "$KEY" -N ""
  fi

  info "3) Starting ssh-agent & adding key…"
  eval "$(ssh-agent -s)"
  ssh-add "$KEY"

  echo
  info "4) Add this public key to GitHub:"
  cat "${KEY}.pub"
  echo
  read -rp "Press Enter once added…"

  info "5) Cloning private bootstrap repo…"
  if [[ -d $HOME/arch-bootstrap ]]; then
    warn "Directory ~/arch-bootstrap exists; skipping clone."
  else
    git clone "$PRIVATE_REPO" "$HOME/arch-bootstrap"
  fi

  info "Running private installer…"
  cd "$HOME/arch-bootstrap"
  sudo ./bootstrap.sh

  info "Bootstrap complete! 🎉"
  exit 0
fi

# ——— Mis-invocation ———
error "Usage: run as root: $SCRIPT_PATH"
exit 1

