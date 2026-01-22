#!/bin/zsh
# Git module for forgexx

# Register the git module
module_register "git" \
    "Git global configuration" \
    "git_backup" \
    "git_restore" \
    "git_status"

# Backup Git configuration
git_backup() {
    local repo_dir=$1
    local git_dir="$repo_dir/git"
    mkdir -p "$git_dir"

    # Backup .gitconfig
    if [[ -f "$HOME/.gitconfig" ]]; then
        cp "$HOME/.gitconfig" "$git_dir/"
        log_debug "Backed up .gitconfig"
    fi

    # Backup .gitignore_global
    if [[ -f "$HOME/.gitignore_global" ]]; then
        cp "$HOME/.gitignore_global" "$git_dir/"
        log_debug "Backed up .gitignore_global"
    fi

    log_success "Git configuration backed up"
    return 0
}

# Restore Git configuration
git_restore() {
    local repo_dir=$1
    local git_dir="$repo_dir/git"

    if [[ ! -d "$git_dir" ]]; then
        log_warning "Git backup not found"
        return 1
    fi

    # Restore .gitconfig
    if [[ -f "$git_dir/.gitconfig" ]]; then
        cp "$git_dir/.gitconfig" "$HOME/.gitconfig"
        log_debug "Restored .gitconfig"
    fi

    # Restore .gitignore_global
    if [[ -f "$git_dir/.gitignore_global" ]]; then
        cp "$git_dir/.gitignore_global" "$HOME/.gitignore_global"
        log_debug "Restored .gitignore_global"
    fi

    log_success "Git configuration restored"
    return 0
}

# Show Git status
git_status() {
    echo "  Git:"
    if command_exists git; then
        echo "    Status: $(git --version 2>/dev/null)"
        echo "    Config: $([[ -f "$HOME/.gitconfig" ]] && echo "Found" || echo "Not found")"
        if [[ -f "$HOME/.gitignore_global" ]]; then
            echo "    Global gitignore: Found"
        fi
    else
        echo "    Status: Not installed"
    fi
}
