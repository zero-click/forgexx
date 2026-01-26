#!/bin/zsh
# Tmux module for forgexx

# Register the tmux module
module_register "tmux" \
    "Tmux configuration and plugin management" \
    "tmux_backup" \
    "tmux_restore" \
    "tmux_status"

# Tmux Plugin Manager (TPM) installation directory
local TPM_DIR="$HOME/.tmux/plugins/tpm"
local TPM_REPO="https://github.com/tmux-plugins/tpm"

# Backup Tmux configuration
tmux_backup() {
    local repo_dir=$1
    local tmux_dir="$repo_dir/tmux"
    mkdir -p "$tmux_dir"

    # Backup .tmux.conf
    if [[ -f "$HOME/.tmux.conf" ]]; then
        cp "$HOME/.tmux.conf" "$tmux_dir/"
        log_debug "Backed up .tmux.conf"
    else
        log_warning ".tmux.conf not found"
    fi

    log_success "Tmux configuration backed up"
    return 0
}

# Restore Tmux configuration
tmux_restore() {
    local repo_dir=$1
    local tmux_dir="$repo_dir/tmux"

    if [[ ! -d "$tmux_dir" ]]; then
        log_warning "Tmux backup not found"
        return 1
    fi

    # Step 1: Ensure TPM is installed
    if [[ ! -d "$TPM_DIR" ]]; then
        log_info "Installing Tmux Plugin Manager (TPM)..."
        if command_exists git; then
            git clone "$TPM_REPO" "$TPM_DIR"
            log_success "TPM installed to $TPM_DIR"
        else
            log_error "Git is required to install TPM"
            return 1
        fi
    else
        log_debug "TPM already installed at $TPM_DIR"
    fi

    # Step 2: Restore .tmux.conf
    if [[ -f "$tmux_dir/.tmux.conf" ]]; then
        # Backup existing .tmux.conf if it exists
        if [[ -f "$HOME/.tmux.conf" ]]; then
            cp "$HOME/.tmux.conf" "$HOME/.tmux.conf.bak"
            log_debug "Backed up existing .tmux.conf to .tmux.conf.bak"
        fi
        cp "$tmux_dir/.tmux.conf" "$HOME/.tmux.conf"
        log_debug "Restored .tmux.conf"
    else
        log_warning ".tmux.conf not found in backup"
        return 1
    fi

    # Step 3: Install plugins using TPM
    log_info "Installing tmux plugins..."
    if [[ -x "$TPM_DIR/bin/install_plugins" ]]; then
        "$TPM_DIR/bin/install_plugins"
        log_success "Tmux plugins installed"
    else
        log_warning "TPM install_plugins script not found or not executable"
        log_info "You may need to install plugins manually by pressing: prefix + I"
    fi

    log_success "Tmux configuration and plugins restored"
    return 0
}

# Show Tmux status
tmux_status() {
    echo "  Tmux:"
    if command_exists tmux; then
        echo "    Status: $(tmux -V 2>/dev/null)"
        echo "    Config: $([[ -f "$HOME/.tmux.conf" ]] && echo "Found" || echo "Not found")"

        # Check TPM status
        if [[ -d "$TPM_DIR" ]]; then
            local tpm_version=$(cd "$TPM_DIR" && git describe --tags --abbrev=0 2>/dev/null)
            echo "    TPM: Installed (version: ${tpm_version:-unknown})"
        else
            echo "    TPM: Not installed"
        fi
    else
        echo "    Status: Not installed"
    fi
}
