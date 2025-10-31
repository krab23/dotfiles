#!/bin/bash
# Script to set up Zsh, Starship, and Neovim

# --- CONFIGURATION (EDIT THESE LINES) ---
DOTFILES_REPO="krab23/dotfiles.git"
DOTFILES_URL="https://github.com/${DOTFILES_REPO}"
DOTFILES_DIR="$HOME/dotfiles"
# --- END CONFIGURATION ---

# --- 0. Prerequisites & Zsh Setup ---
echo "0. Installing prerequisites (Zsh, Git, Curl) and Oh My Zsh..."
sudo apt update
# Ensure Zsh, Git, and Curl are present (harmless if already installed)
sudo apt install -y zsh curl git

# Install Oh My Zsh only if it doesn't exist
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
    echo "Oh My Zsh already exists. Skipping install."
fi

# Set Zsh as default (harmless if already set)
chsh -s $(which zsh)

# --- 1. Clone or Pull Your Dotfiles Repository ---
echo "1. Cloning/Updating your dotfiles repository..."
if [ -d "$DOTFILES_DIR" ]; then
    echo "Dotfiles directory exists. Pulling latest changes..."
    # If the repo exists, navigate and pull the latest changes
    git -C "$DOTFILES_DIR" pull
else
    # If the repo does not exist, clone it
    echo "Cloning dotfiles for the first time..."
    git clone "$DOTFILES_URL" "$DOTFILES_DIR"
fi


# --- 2. Install Starship.rs ---
echo "2. Installing Starship (the cross-shell prompt)..."
# Check if starship is installed and if not, install it.
if ! command -v starship &> /dev/null; then
    curl -sS https://starship.rs/install.sh | sh
else
    echo "Starship binary already exists. Skipping install."
fi

# Symlink your Starship config (Use -f to FORCE overwrite existing symlink/file)
echo "Overwriting Starship config..."
mkdir -p ~/.config
ln -sf "$DOTFILES_DIR/starship/starship.toml" ~/.config/starship.toml

# Add Starship init line to .zshrc (using echo >> is safe as long as the line is not duplicated)
# Note: Since we overwrite the .zshrc later, this step is moved to final symlink.


# --- 3. Install Neovim and Configuration ---
echo "3. Installing Neovim and custom configuration..."

if ! command -v nvim &> /dev/null; then
    echo "Installing Neovim AppImage..."
    curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim.appimage
    chmod u+x nvim.appimage
    sudo mv nvim.appimage /usr/local/bin/nvim
else
    echo "Neovim binary already exists. Skipping install."
fi

# Symlink your Neovim configuration directory (Use -f to FORCE overwrite)
echo "Overwriting Neovim config symlink..."
ln -sf "$DOTFILES_DIR/nvim" ~/.config/nvim


# --- 4. Final .zshrc Link ---
# Overwrite the default .zshrc with your custom one.
echo "4. Overwriting default .zshrc with your custom one..."

# Force the final symlink (-f)
ln -sf "$DOTFILES_DIR/zsh/zshrc" ~/.zshrc

# --- Final Step ---
echo "--- Installation Complete! ---"
echo "NOTE: Log out and log back in (or run 'exec zsh') to fully load your new environment."
