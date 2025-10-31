#!/bin/bash
# Script to set up Zsh, Starship, and Neovim for Debian

# --- CONFIGURATION (EDIT THESE LINES) ---
DOTFILES_REPO="krab23/dotfiles.git"
DOTFILES_DIR="$HOME/dotfiles"
# --- END CONFIGURATION ---

# --- 0. Prerequisites & Zsh Setup (from previous step) ---
echo "0. Installing prerequisites (Zsh, Git, Curl) and Oh My Zsh..."
sudo apt update
sudo apt install -y zsh curl

# Install Oh My Zsh (silent/unattended mode)
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Set Zsh as default (requires relog for change to take effect)
chsh -s $(which zsh)

# --- 1. Clone Your Dotfiles Repository ---
echo "1. Cloning your dotfiles repository..."
git clone "https://github.com/${DOTFILES_REPO}" $DOTFILES_DIR

# --- 2. Install Starship.rs ---
echo "2. Installing Starship (the cross-shell prompt)..."
curl -sS https://starship.rs/install.sh | sh

# Symlink your Starship config
mkdir -p ~/.config
ln -sf "$DOTFILES_DIR/starship/starship.toml" ~/.config/starship.toml

# --- 3. Install Neovim and Configuration ---
echo "3. Installing Neovim and custom configuration..."
# Use the official Neovim AppImage for the latest version
curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim.appimage
chmod u+x nvim.appimage
sudo mv nvim.appimage /usr/local/bin/nvim

# Symlink your Neovim configuration directory
# Assumes your config is at $DOTFILES_DIR/nvim
ln -sf "$DOTFILES_DIR/nvim" ~/.config/nvim

# --- 4. Final .zshrc Link ---
# Overwrite the default .zshrc with your custom one (which should include plugin configs)
echo "4. Overwriting default .zshrc with your custom one..."
ln -sf "$DOTFILES_DIR/zsh/.zshrc" ~/.zshrc

# --- Final Step ---
echo "--- Installation Complete! ---"
echo "NOTE: Log out and log back in (or run 'exec zsh') to fully load your new environment."
echo "Neovim will install plugins on first run."
