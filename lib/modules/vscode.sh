#!/bin/zsh
# VSCode module for forgexx

# Register the vscode module
module_register "vscode" \
    "VS Code settings and extensions" \
    "vscode_backup" \
    "vscode_restore" \
    "vscode_status"

# VSCode paths
VSCODE_SETTINGS_DIR="${VSCODE_SETTINGS_DIR:-$HOME/Library/Application Support/Code/User}"

# Backup VSCode settings and extensions
vscode_backup() {
    local repo_dir=$1
    local vscode_dir="$repo_dir/vscode"

    mkdir -p "$vscode_dir"

    log_info "Backing up VSCode configuration..."

    # Backup settings
    if [[ -d "$VSCODE_SETTINGS_DIR" ]]; then
        cp "$VSCODE_SETTINGS_DIR/settings.json" "$vscode_dir/" 2>/dev/null
        cp "$VSCODE_SETTINGS_DIR/keybindings.json" "$vscode_dir/" 2>/dev/null
        cp "$VSCODE_SETTINGS_DIR/snippets"/*.json "$vscode_dir/snippets/" 2>/dev/null || true
        log_debug "Backed up VSCode settings"
    fi

    # Backup extensions list
    if command_exists code; then
        code --list-extensions > "$vscode_dir/extensions.txt"
        log_debug "Backed up VSCode extensions"
    fi

    log_success "VSCode configuration backed up"
    return 0
}

# Restore VSCode settings and extensions
vscode_restore() {
    local repo_dir=$1
    local vscode_dir="$repo_dir/vscode"

    if ! command_exists code; then
        log_warning "VSCode not installed, skipping..."
        return 0
    fi

    log_info "Restoring VSCode configuration..."

    # Create settings directory if it doesn't exist
    mkdir -p "$VSCODE_SETTINGS_DIR"

    # Restore settings
    if [[ -f "$vscode_dir/settings.json" ]]; then
        cp "$vscode_dir/settings.json" "$VSCODE_SETTINGS_DIR/"
        log_debug "Restored settings.json"
    fi

    if [[ -f "$vscode_dir/keybindings.json" ]]; then
        cp "$vscode_dir/keybindings.json" "$VSCODE_SETTINGS_DIR/"
        log_debug "Restored keybindings.json"
    fi

    # Restore snippets
    if [[ -d "$vscode_dir/snippets" ]]; then
        mkdir -p "$VSCODE_SETTINGS_DIR/snippets"
        cp "$vscode_dir/snippets"/*.json "$VSCODE_SETTINGS_DIR/snippets/" 2>/dev/null || true
        log_debug "Restored snippets"
    fi

    # Restore extensions
    if [[ -f "$vscode_dir/extensions.txt" ]]; then
        log_info "Installing VSCode extensions..."
        while IFS= read -r extension; do
            if [[ -n "$extension" ]]; then
                log_debug "Installing extension: $extension"
                code --install-extension "$extension" --force 2>&1 | grep -v "^$" || true
            fi
        done < "$vscode_dir/extensions.txt"
        log_success "VSCode extensions installed"
    fi

    log_success "VSCode configuration restored"
    return 0
}

# Show VSCode status
vscode_status() {
    local repo_dir=$1
    local vscode_dir="$repo_dir/vscode"

    echo "  VSCode:"
    if command_exists code; then
        echo "    Status: Installed ($(code --version | head -n1))"
        if [[ -f "$vscode_dir/extensions.txt" ]]; then
            local count=$(wc -l < "$vscode_dir/extensions.txt" | tr -d ' ')
            echo "    Extensions: $count in backup"
        else
            echo "    Extensions: No backup found"
        fi
    else
        echo "    Status: Not installed"
    fi
}
