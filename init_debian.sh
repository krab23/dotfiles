#!/bin/bash
# Script to set up Zsh, Starship, and Neovim

# --- CONFIGURATION (EDIT THESE LINES) ---
DOTFILES_REPO="krab23/dotfiles.git"
DOTFILES_URL="https://github.com/${DOTFILES_REPO}"
DOTFILES_DIR="$HOME/dotfiles"
NEOVIM_FILE="nvim-linux-x86_64.appimage"
# --- END CONFIGURATION ---

# --- 0. Prerequisites & Zsh Setup ---
echo "0. Installing prerequisites (Zsh, Git, Curl) and Oh My Zsh..."
sudo apt update
# Ensure Zsh, Git, and Curl are present (harmless if already installed)
sudo apt install -y zsh curl git

# ---  Install Docker Engine and Docker Compose ---
echo "Installing Docker Engine and Docker Compose..."

# Check if Docker is already installed
if ! command -v docker &> /dev/null; then
    echo "Docker not found. Proceeding with installation..."
    
    # 1. Add Docker's official GPG key
    sudo apt update
    sudo apt install -y ca-certificates curl gnupg lsb-release
    
    # Create the keyrings directory if it doesn't exist
    sudo install -m 0755 -d /etc/apt/keyrings
    
    # Download and save the GPG key
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    # 2. Add the Docker repository to Apt sources
    echo \
      "deb [arch=\"$(dpkg --print-architecture)\" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
      \"$(. /etc/os-release && echo \"$VERSION_CODENAME\")\" stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # 3. Install Docker Engine, CLI, and Compose
    sudo apt update
    # Install the main packages
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # 4. Manage Docker as a non-root user (CRITICAL STEP)
    # Add the current user ($USER) to the docker group
    echo "Adding user '$USER' to the 'docker' group. You will need to log out/in."
    sudo usermod -aG docker "$USER"
    
else
    echo "Docker already exists. Skipping installation."
fi

# --- Set up Automated Docker Cleanup Cron Job ---
echo "Setting up daily Docker cleanup cron job (pruning)."

# The command to run: Docker system prune -a (all unused) and -f (force/non-interactive)
PRUNE_COMMAND="/usr/bin/docker system prune -a -f"

# The cron schedule (e.g., 3:00 AM every day)
CRON_SCHEDULE="0 3 * * *"

# Check if the job already exists in the crontab to prevent duplication
if ! sudo crontab -l | grep -q "$PRUNE_COMMAND"; then
    # If the job is NOT found, append it to the current user's crontab
    (sudo crontab -l 2>/dev/null; echo "$CRON_SCHEDULE $PRUNE_COMMAND") | sudo crontab -
    echo "Successfully added: $CRON_SCHEDULE $PRUNE_COMMAND"
else
    echo "Daily prune job already exists. Skipping."
fi

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
    echo "Downloading Neovim AppImage: $NEOVIM_FILE"
    curl -LO https://github.com/neovim/neovim/releases/latest/download/$NEOVIM_FILE
    chmod u+x $NEOVIM_FILE
    echo "Extracting Neovim binary..."
    ./$NEOVIM_FILE --appimage-extract > /dev/null 2>&1
    # Find the extracted binary and move it to a PATH location
    sudo mv squashfs-root/usr/* /usr/local/    
    # Clean up the downloaded file and the extracted directory
    rm -rf $NEOVIM_FILE squashfs-root
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
