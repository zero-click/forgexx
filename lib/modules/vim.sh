#!/bin/zsh
# Vim module for forgexx

# Register the vim module
module_register "vim" \
    "Vim configuration and plugin management" \
    "vim_backup" \
    "vim_restore" \
    "vim_status"

# Vundle installation directory
local VUNDLE_DIR="$HOME/.vim/bundle/Vundle.vim"
local VUNDLE_REPO="https://github.com/VundleVim/Vundle.vim.git"

# Backup Vim configuration
vim_backup() {
    local repo_dir=$1
    local vim_dir="$repo_dir/vim"
    mkdir -p "$vim_dir"

    # Backup .vimrc
    if [[ -f "$HOME/.vimrc" ]]; then
        cp "$HOME/.vimrc" "$vim_dir/"
        log_debug "Backed up .vimrc"
    else
        log_warning ".vimrc not found"
    fi

    log_success "Vim configuration backed up"
    return 0
}

# Restore Vim configuration
vim_restore() {
    local repo_dir=$1
    local vim_dir="$repo_dir/vim"

    if [[ ! -d "$vim_dir" ]]; then
        log_warning "Vim backup not found"
        return 1
    fi

    # Step 1: Ensure Vundle is installed
    if [[ ! -d "$VUNDLE_DIR" ]]; then
        log_info "Installing Vundle (Vim plugin manager)..."
        if command_exists git; then
            mkdir -p "$HOME/.vim/bundle"
            git clone "$VUNDLE_REPO" "$VUNDLE_DIR"
            log_success "Vundle installed to $VUNDLE_DIR"
        else
            log_error "Git is required to install Vundle"
            return 1
        fi
    else
        log_debug "Vundle already installed at $VUNDLE_DIR"
    fi

    # Step 2: Restore .vimrc
    if [[ -f "$vim_dir/.vimrc" ]]; then
        # Backup existing .vimrc if it exists
        if [[ -f "$HOME/.vimrc" ]]; then
            cp "$HOME/.vimrc" "$HOME/.vimrc.bak"
            log_debug "Backed up existing .vimrc to .vimrc.bak"
        fi
        cp "$vim_dir/.vimrc" "$HOME/.vimrc"
        log_debug "Restored .vimrc"
    else
        log_warning ".vimrc not found in backup"
        return 1
    fi

    # Step 3: Install plugins using Vundle
    log_info "Installing vim plugins..."
    if command_exists vim; then
        # Run vim in headless mode to install plugins
        vim +PluginInstall +qall >/dev/null 2>&1
        log_success "Vim plugins installed"
    else
        log_warning "Vim not found. Skipping plugin installation."
        log_info "Please install vim and run: vim +PluginInstall +qall"
    fi

    log_success "Vim configuration and plugins restored"
    return 0
}

# Show Vim status
vim_status() {
    echo "  Vim:"
    if command_exists vim; then
        local vim_version=$(vim --version | head -1 | awk '{print $5}')
        echo "    Status: Installed (version: $vim_version)"
        echo "    Config: $([[ -f "$HOME/.vimrc" ]] && echo "Found" || echo "Not found")"

        # Check Vundle status
        if [[ -d "$VUNDLE_DIR" ]]; then
            local vundle_version=$(cd "$VUNDLE_DIR" && git describe --tags --abbrev=0 2>/dev/null)
            echo "    Vundle: Installed (version: ${vundle_version:-unknown})"
        else
            echo "    Vundle: Not installed"
        fi
    else
        echo "    Status: Not installed"
    fi
}
