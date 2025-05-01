#!/usr/bin/env bash
#
# arch-bootstrap.sh – Unified Arch Linux bootstrap (root + user phases)
#
# Usage:
#   As root (installer environment): ./arch-bootstrap.sh
#
# Behaviors:
#   • Root-phase (EUID=0, no --as-user flag):
#     1) Update system
#     2) Install sudo & git
#     3) Enable wheel NOPASSWD
#     4) Create user 'asimas'
#     → then re-invoke user-phase via runuser + stdin
#
#   • User-phase (--as-user flag under non-root):
#     1) Install openssh
#     2) Generate Ed25519 key if missing
#     3) Start ssh-agent & ssh-add
#     4) Prompt to add pubkey to GitHub
#     5) Clone private repo & run its bootstrap.sh

set -euo pipefail
trap 'error "Unexpected error on line $LINENO."; exit 1' ERR
trap 'info "Interrupted by user."; exit 130' INT

# ——— Logging ———
info ()  { printf "\033[1;34m[INFO]\033[0m  %s\n" "$*"; }
warn ()  { printf "\033[1;33m[WARN]\033[0m  %s\n" "$*"; }
error () { printf "\033[1;31m[ERROR]\033[0m %s\n" "$*" >&2; }

# ——— Config ———
BOOT_USER="asimas"
SHELL_PATH="/bin/bash"
SSH_EMAIL="austin@simas.io"
PRIVATE_REPO="git@github.com:ajsimas/arch-bootstrap.git"
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"

# ——— Root-phase ———
if [[ $EUID -eq 0 && "${1:-}" != "--as-user" ]]; then
  info "== Root-phase starting =="

  info "1) Updating package database & system…"
  pacman -Syu --noconfirm

  info "2) Installing sudo & git…"
  pacman -S --noconfirm --needed sudo git

  info "3) Enabling wheel group passwordless sudo…"
  cat >/etc/sudoers.d/wheel << 'EOF'
%wheel ALL=(ALL) NOPASSWD: ALL
EOF
  chmod 0440 /etc/sudoers.d/wheel

  info "4) Creating user '$BOOT_USER'…"
  if id "$BOOT_USER" &>/dev/null; then
    warn "User '$BOOT_USER' already exists; skipping creation."
  else
    useradd -m -G wheel -s "$SHELL_PATH" "$BOOT_USER"
    info "Please set a password for '$BOOT_USER':"
    passwd "$BOOT_USER"
  fi

  info "Root-phase complete. Switching to user-phase…"
  # Stream this very script into the new user's shell session
  exec runuser -u "$BOOT_USER" -- bash -s -- --as-user < "$SCRIPT_PATH"
fi

# ——— User-phase ———
if [[ "${1:-}" == "--as-user" ]]; then
  if [[ $EUID -eq 0 ]]; then
    error "Refusing to run user-phase as root."
    exit 1
  fi
  info "== User-phase starting as '$(whoami)' =="

  info "1) Installing OpenSSH client…"
  sudo pacman -S --noconfirm --needed openssh

  info "2) Generating SSH key (Ed25519)…"
  KEY="$HOME/.ssh/id_ed25519"
  if [[ -f $KEY ]]; then
    warn "SSH key already exists at $KEY; skipping keygen."
  else
    mkdir -p ~/.ssh && chmod 700 ~/.ssh
    ssh-keygen -t ed25519 -C "$SSH_EMAIL" -f "$KEY" -N ""
  fi

  info "3) Starting ssh-agent & adding key…"
  eval "$(ssh-agent -s)"
  ssh-add "$KEY"

  echo
  info "4) Copy the following public key into GitHub → Settings → SSH and GPG keys:"
  cat "${KEY}.pub"
  echo
  read -rp "Press Enter once added to GitHub…"

  info "5) Cloning your private bootstrap repo…"
  if [[ -d $HOME/arch-bootstrap ]]; then
    warn "~/arch-bootstrap already exists; skipping clone."
  else
    git clone "$PRIVATE_REPO" "$HOME/arch-bootstrap"
  fi

  info "Running private repo installer…"
  cd "$HOME/arch-bootstrap"
  sudo ./bootstrap.sh

  info "All done! 🎉 You’re bootstrapped."
  exit 0
fi

# ——— Usage error ———
error "This script must be run as root: ./arch-bootstrap.sh"
exit 1
