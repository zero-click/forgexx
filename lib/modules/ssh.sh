#!/bin/zsh
# SSH module for forgexx

# Register the ssh module
module_register "ssh" \
    "SSH config and public keys" \
    "ssh_backup" \
    "ssh_restore" \
    "ssh_status"

# Backup SSH configuration
ssh_backup() {
    local repo_dir=$1
    local ssh_dir="$repo_dir/ssh"
    mkdir -p "$ssh_dir"

    # Backup config file
    if [[ -f "$HOME/.ssh/config" ]]; then
        cp "$HOME/.ssh/config" "$ssh_dir/"
        log_debug "Backed up SSH config"
    fi

    # Backup public keys only (not private keys for security)
    if [[ -d "$HOME/.ssh" ]]; then
        find "$HOME/.ssh" -maxdepth 1 -name "*.pub" -exec cp {} "$ssh_dir/" \;
        local pub_key_count=$(find "$ssh_dir" -name "*.pub" 2>/dev/null | wc -l | tr -d ' ')
        log_debug "Backed up $pub_key_count public key(s)"
    fi

    log_success "SSH configuration backed up"
    return 0
}

# Restore SSH configuration
ssh_restore() {
    local repo_dir=$1
    local ssh_dir="$repo_dir/ssh"

    if [[ ! -d "$ssh_dir" ]]; then
        log_warning "SSH backup not found"
        return 1
    fi

    # Create .ssh directory if it doesn't exist
    mkdir -p "$HOME/.ssh"

    # Restore config
    if [[ -f "$ssh_dir/config" ]]; then
        cp "$ssh_dir/config" "$HOME/.ssh/"
        log_debug "Restored SSH config"
    fi

    # Restore public keys
    if ls "$ssh_dir"/*.pub &>/dev/null; then
        cp "$ssh_dir"/*.pub "$HOME/.ssh/"
        log_debug "Restored SSH public keys"
    fi

    log_success "SSH configuration restored"
    return 0
}

# Show SSH status
ssh_status() {
    echo "  SSH:"
    if [[ -d "$HOME/.ssh" ]]; then
        echo "    Config: $([[ -f "$HOME/.ssh/config" ]] && echo "Found" || echo "Not found")"
        local pub_keys=$(find "$HOME/.ssh" -maxdepth 1 -name "*.pub" 2>/dev/null | wc -l | tr -d ' ')
        echo "    Public keys: $pub_keys"
    else
        echo "    Status: .ssh directory not found"
    fi
}
