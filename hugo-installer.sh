#!/bin/bash

# Function to install man for multiple Linux distributions
install_man_page() {
  if command -v man &>/dev/null; then
    echo "man is already installed."
  else
    echo "Installing man requires superuser privileges..."
    
    if [ -f /etc/os-release ]; then
      source /etc/os-release
      case "$ID" in
        ubuntu|debian)
          sudo apt update && sudo apt install -y man-db
          ;;
        fedora|rhel|centos)
          sudo dnf install -y man-db
          ;;
        arch|manjaro)
          sudo pacman -Syu man-db --noconfirm
          ;;
        opensuse)
          sudo zypper install -y man
          ;;
        *)
          echo "Unsupported distribution: $ID. Please install 'man' manually."
          ;;
      esac
    else
      echo "Cannot determine Linux distribution. Please install 'man' manually."
    fi
  fi
}

# Prompt for sudo if needed
prompt_for_password() {
  echo "Superuser privileges are required to move the Hugo binary to /usr/local/bin and install man pages and shell completion files."
  echo "Please enter your password to proceed:"
  sudo -v || { echo "Aborting due to insufficient privileges."; exit 1; }
}

# Change to temporary directory
pushd /tmp/

# Install man page support if missing
install_man_page

# Get current installed version
if test -f "/usr/local/bin/hugo"; then
  _currentver=$(/usr/local/bin/hugo version | grep -m 1 -Eo '[0-9]{1,}\.[0-9]{1,}\.[0-9]{1,}')
else
  _currentver="Not installed"
fi

# Fetch the latest version from GitHub
_latestver=$(curl --silent -N "https://api.github.com/repos/gohugoio/hugo/tags" | grep -m 1 -Eo '[0-9]{1,}\.[0-9]{1,}\.[0-9]{1,}')

# Ask user for extended version, default to Yes if Enter is pressed
read -p "Do you want to install Hugo extended version? (Y/n): " _install_extended
_install_extended=${_install_extended:-Y}

if [[ "$_install_extended" =~ ^[Yy]$ ]]; then
  _version_type="extended"
else
  _version_type=""
fi

# Ask user for a specific version or use the latest version
read -p "Enter the version of Hugo you want to install (or press Enter to install the latest version $_latestver): " _userversion

# If user doesn't provide a version, use the latest version
if [ -z "$_userversion" ]; then
  _userversion="$_latestver"
fi

echo "Chosen version: $_userversion"
echo "Current version: $_currentver"

# Proceed with installation if the chosen version is different from the installed version
if [ "$_userversion" != "$_currentver" ]; then

  echo "Downloading hugo v${_userversion} (${_version_type})"
  curl -L "https://github.com/gohugoio/hugo/releases/download/v${_userversion}/hugo_${_version_type}_${_userversion}_Linux-64bit.tar.gz" --progress-bar >hugo_${_version_type}_${_userversion}_Linux-64bit.tar.gz

  echo "Extracting hugo binary..."
  tar xvfz hugo_${_version_type}_${_userversion}_Linux-64bit.tar.gz hugo

  # Prompt for password for privileged operations
  prompt_for_password

  # Make hugo binary executable
  echo "Making hugo executable..."
  chmod +x hugo

  # Move hugo binary to a location that is already in your PATH
  echo "Moving hugo to /usr/local/bin..."
  sudo mv hugo /usr/local/bin/

  # Use the full path for Hugo binary to avoid command not found issues
  hugo_bin="/usr/local/bin/hugo"

  # Install man pages to /usr/share/man
  echo "Installing man pages..."
  sudo mkdir -p /usr/share/man/man1
  sudo rm /usr/share/man/man1/hugo* -rf
  sudo hugo gen man --dir /usr/share/man/man1

  # Update man database
  sudo mandb

  # Install shell completion files
  echo "Installing bash completion..."
  sudo mkdir -p /usr/local/share/bash-completion/completions/
  sudo hugo completion bash | sudo tee /usr/local/share/bash-completion/completions/hugo >/dev/null
  
  echo "Installing fish completion..."
  sudo mkdir -p /usr/local/share/fish/completions/
  sudo hugo completion fish | sudo tee /usr/local/share/fish/completions/hugo.fish >/dev/null

  echo "Installing zsh completion..."
  sudo mkdir -p /usr/local/share/zsh/site-functions/
  sudo hugo completion zsh | sudo tee /usr/local/share/zsh/site-functions/_hugo >/dev/null

  # Go back to previous directory
  popd

  # Display hugo binary location and version
  location="$(which hugo)"
  echo "Hugo binary location: $location"
  version="$($hugo_bin version)"
  echo "Hugo binary version: $version"
else
  echo "Chosen version ${_userversion} is already installed"
fi
