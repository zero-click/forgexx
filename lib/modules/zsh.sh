#!/bin/zsh
# Zsh module for forgexx

# Register the zsh module
module_register "zsh" \
    "Zsh configuration and plugin management" \
    "zsh_backup" \
    "zsh_restore" \
    "zsh_status"

# oh-my-zsh installation directory
local ZSH_DIR="$HOME/.oh-my-zsh"
local ZSH_REPO="https://github.com/ohmyzsh/ohmyzsh.git"

# zplug installation directory
local ZPLUG_DIR="$HOME/.zplug"
local ZPLUG_REPO="https://github.com/zplug/zplug.git"

# Backup Zsh configuration
zsh_backup() {
    local repo_dir=$1
    local zsh_dir="$repo_dir/zsh"
    mkdir -p "$zsh_dir"

    # Backup .zshrc
    if [[ -f "$HOME/.zshrc" ]]; then
        cp "$HOME/.zshrc" "$zsh_dir/"
        log_debug "Backed up .zshrc"
    else
        log_warning ".zshrc not found"
    fi

    log_success "Zsh configuration backed up"
    return 0
}

# Restore Zsh configuration
zsh_restore() {
    local repo_dir=$1
    local zsh_dir="$repo_dir/zsh"

    if [[ ! -d "$zsh_dir" ]]; then
        log_warning "Zsh backup not found"
        return 1
    fi

    # Step 1: Ensure oh-my-zsh is installed
    if [[ ! -d "$ZSH_DIR" ]]; then
        log_info "Installing oh-my-zsh..."
        if command_exists git; then
            git clone "$ZSH_REPO" "$ZSH_DIR"
            log_success "oh-my-zsh installed to $ZSH_DIR"
        else
            log_error "Git is required to install oh-my-zsh"
            return 1
        fi
    else
        log_debug "oh-my-zsh already installed at $ZSH_DIR"
    fi

    # Step 2: Ensure zplug is installed
    if [[ ! -d "$ZPLUG_DIR" ]]; then
        log_info "Installing zplug (Zsh plugin manager)..."
        if command_exists git; then
            git clone "$ZPLUG_REPO" "$ZPLUG_DIR"
            log_success "zplug installed to $ZPLUG_DIR"
        else
            log_error "Git is required to install zplug"
            return 1
        fi
    else
        log_debug "zplug already installed at $ZPLUG_DIR"
    fi

    # Step 3: Restore .zshrc
    if [[ -f "$zsh_dir/.zshrc" ]]; then
        # Backup existing .zshrc if it exists
        if [[ -f "$HOME/.zshrc" ]]; then
            cp "$HOME/.zshrc" "$HOME/.zshrc.bak"
            log_debug "Backed up existing .zshrc to .zshrc.bak"
        fi
        cp "$zsh_dir/.zshrc" "$HOME/.zshrc"
        log_debug "Restored .zshrc"
    else
        log_warning ".zshrc not found in backup"
        return 1
    fi

    # Step 4: Install plugins using zplug
    log_info "Installing zsh plugins..."
    if command_exists zplug; then
        # Source zshrc to load zplug configuration, then install
        zsh -c "source $HOME/.zshrc && zplug install" 2>/dev/null
        log_success "Zsh plugins installed"
    else
        log_warning "zplug not found in PATH. Skipping plugin installation."
        log_info "You may need to add zplug to PATH or run: zplug install"
    fi

    log_success "Zsh configuration and plugins restored"
    return 0
}

# Show Zsh status
zsh_status() {
    echo "  Zsh:"
    if command_exists zsh; then
        local zsh_version=$(zsh --version | awk '{print $2}')
        echo "    Status: Installed (version: $zsh_version)"
        echo "    Config: $([[ -f "$HOME/.zshrc" ]] && echo "Found" || echo "Not found")"

        # Check oh-my-zsh status
        if [[ -d "$ZSH_DIR" ]]; then
            local omz_version=$(cd "$ZSH_DIR" && git describe --tags --abbrev=0 2>/dev/null)
            echo "    oh-my-zsh: Installed (version: ${omz_version:-unknown})"
        else
            echo "    oh-my-zsh: Not installed"
        fi

        # Check zplug status
        if [[ -d "$ZPLUG_DIR" ]]; then
            local zplug_version=$(cd "$ZPLUG_DIR" && git describe --tags --abbrev=0 2>/dev/null)
            echo "    zplug: Installed (version: ${zplug_version:-unknown})"
        else
            echo "    zplug: Not installed"
        fi
    else
        echo "    Status: Not installed"
    fi
}
