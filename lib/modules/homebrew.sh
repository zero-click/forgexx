#!/bin/zsh
# Homebrew module for forgexx

# Register the homebrew module
module_register "homebrew" \
    "Homebrew packages and casks" \
    "homebrew_backup" \
    "homebrew_restore" \
    "homebrew_status"

# Backup Homebrew packages
homebrew_backup() {
    local repo_dir=$1
    local brewfile_dir="$repo_dir/homebrew"

    if ! command_exists brew; then
        log_warning "Homebrew not installed, skipping..."
        return 0
    fi

    mkdir -p "$brewfile_dir"

    log_info "Dumping Homebrew packages..."

    # Dump all packages, casks, and mas apps
    brew bundle dump --file="$brewfile_dir/Brewfile" --force --all

    return 0
}

# Restore Homebrew packages
homebrew_restore() {
    local repo_dir=$1
    local brewfile_dir="$repo_dir/homebrew"

    if ! command_exists brew; then
        log_error "Homebrew not installed. Please install it first:"
        echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        return 1
    fi

    if [[ ! -f "$brewfile_dir/Brewfile" ]]; then
        log_warning "Brewfile not found at $brewfile_dir/Brewfile"
        return 1
    fi

    log_info "Installing Homebrew packages..."
    log_warning "This may take a while and require sudo access..."

    # Ask for confirmation
    if ! confirm "Install Homebrew packages from $brewfile_dir/Brewfile?" "n"; then
        log_info "Skipped Homebrew restore"
        return 0
    fi

    # Install from Brewfile
    if brew bundle --file="$brewfile_dir/Brewfile"; then
        log_success "Homebrew packages installed successfully"
        return 0
    else
        log_error "Some Homebrew packages failed to install"
        return 1
    fi
}

# Show Homebrew status
homebrew_status() {
    local repo_dir=$1
    local brewfile_dir="$repo_dir/homebrew"

    echo "  Homebrew:"
    if command_exists brew; then
        echo "    Status: $(brew --version | head -n1)"
        if [[ -f "$brewfile_dir/Brewfile" ]]; then
            echo "    Brewfile: Found ($(wc -l < "$brewfile_dir/Brewfile") lines)"
        else
            echo "    Brewfile: Not found"
        fi
    else
        echo "    Status: Not installed"
    fi
}
