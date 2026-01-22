#!/bin/zsh
# Command handlers for forgexx

# Initialize forgexx with a GitHub repository
cmd_init() {
    local github_repo=$1

    if [[ -z "$github_repo" ]]; then
        log_error "Usage: forgexx init <github-repo>"
        echo
        echo "Example:"
        echo "  forgexx init git@github.com:username/dotfiles.git"
        echo "  forgexx init https://github.com/username/dotfiles.git"
        return 1
    fi

    log_info "Initializing forgexx..."
    log_info "GitHub repository: $github_repo"

    # Initialize configuration
    config_init "$github_repo"

    # Try to clone if repository exists, otherwise init new
    if git ls-remote "$github_repo" &>/dev/null; then
        log_info "Repository exists, cloning..."
        if git_clone "$github_repo" "$LOCAL_REPO"; then
            log_success "Repository cloned to $LOCAL_REPO"
        else
            log_warning "Clone failed, you may need to initialize manually"
        fi
    else
        log_info "Repository does not exist yet, will create on first backup"
        git_init "$LOCAL_REPO" "$github_repo"
        log_success "Initialized local repository at $LOCAL_REPO"
        log_info "Remember to create the repository on GitHub and push:"
        echo "  cd $LOCAL_REPO"
        echo "  git push -u origin main"
    fi

    log_success "Forgexx initialized!"
    echo
    config_print
}

# Backup configurations
cmd_backup() {
    config_validate || return 1

    log_info "Starting backup..."

    # Load configuration
    config_load

    # Pull latest changes first
    if [[ -d "$LOCAL_REPO/.git" ]]; then
        log_info "Pulling latest changes from GitHub..."
        git_pull "$LOCAL_REPO" || log_warning "Failed to pull, continuing..."
    fi

    # Run backup for each enabled module (zsh: use ${=VAR} to split on whitespace)
    local failed=0
    for module in ${=ENABLED_MODULES}; do
        if module_is_registered "$module"; then
            if ! module_do_backup "$module" "$LOCAL_REPO"; then
                failed=1
            fi
        else
            log_warning "Module '$module' is not registered, skipping..."
        fi
    done

    # Commit and push changes
    local auto_push=$(config_get FORGEXX_AUTO_PUSH)
    local commit_msg_val=$(config_get FORGEXX_COMMIT_MSG)
    local commit_msg=${commit_msg_val:-"Backup from {{hostname}} at {{timestamp}}"}

    git_sync "$LOCAL_REPO" "$commit_msg" "$auto_push"

    if [[ $failed -eq 0 ]]; then
        log_success "Backup completed successfully!"
    else
        log_warning "Backup completed with some errors"
    fi

    return $failed
}

# Restore configurations
cmd_restore() {
    config_validate || return 1

    log_info "Starting restore..."

    # Pull latest changes first
    if [[ -d "$LOCAL_REPO/.git" ]]; then
        log_info "Pulling latest changes from GitHub..."
        git_pull "$LOCAL_REPO" || log_warning "Failed to pull"
    fi

    # Ask for confirmation
    if ! confirm "This will overwrite your local configurations. Continue?" "n"; then
        log_info "Restore cancelled"
        return 0
    fi

    # Run restore for each enabled module
    local failed=0
    for module in ${=ENABLED_MODULES}; do
        if module_is_registered "$module"; then
            if ! module_do_restore "$module" "$LOCAL_REPO"; then
                failed=1
            fi
        else
            log_warning "Module '$module' is not registered, skipping..."
        fi
    done

    if [[ $failed -eq 0 ]]; then
        log_success "Restore completed successfully!"
        log_info "You may need to restart your shell for changes to take effect."
    else
        log_warning "Restore completed with some errors"
    fi

    return $failed
}

# Show status
cmd_status() {
    config_validate || return 1

    echo "=== Forgexx Status ==="
    echo
    echo "Configuration:"
    config_print
    echo

    echo "Modules:"
    for module in ${=ENABLED_MODULES}; do
        if module_is_registered "$module"; then
            module_do_status "$module" "$LOCAL_REPO"
        fi
    done
    echo

    if [[ -d "$LOCAL_REPO/.git" ]]; then
        echo "Git Repository:"
        git_status "$LOCAL_REPO"
    fi
}

# List available modules
cmd_list_modules() {
    echo "=== Available Modules ==="
    echo
    module_list_all
    echo
    echo "Enable modules in your config file:"
    echo "  export ENABLED_MODULES=\"homebrew dotfiles vscode npm\""
}

# Pull changes from GitHub
cmd_pull() {
    config_validate || return 1

    log_info "Pulling changes from GitHub..."
    if git_pull "$LOCAL_REPO"; then
        log_success "Pulled successfully"
        return 0
    else
        log_error "Pull failed"
        return 1
    fi
}

# Push changes to GitHub
cmd_push() {
    config_validate || return 1

    log_info "Pushing changes to GitHub..."
    if git_push "$LOCAL_REPO"; then
        log_success "Pushed successfully"
        return 0
    else
        log_error "Push failed"
        return 1
    fi
}

# Add a module
cmd_add() {
    local module=$1

    if [[ -z "$module" ]]; then
        log_error "Usage: forgexx add <module>"
        return 1
    fi

    if ! module_is_registered "$module"; then
        log_error "Unknown module: $module"
        echo
        echo "Available modules:"
        cmd_list_modules
        return 1
    fi

    config_load

    if [[ " $ENABLED_MODULES " =~ " $module " ]]; then
        log_warning "Module '$module' is already enabled"
        return 0
    fi

    ENABLED_MODULES="$ENABLED_MODULES $module"
    config_save

    log_success "Module '$module' added to enabled modules"
}

# Remove a module
cmd_remove() {
    local module=$1

    if [[ -z "$module" ]]; then
        log_error "Usage: forgexx remove <module>"
        return 1
    fi

    config_load

    if [[ ! " $ENABLED_MODULES " =~ " $module " ]]; then
        log_warning "Module '$module' is not enabled"
        return 0
    fi

    ENABLED_MODULES="${ENABLED_MODULES//$module/}"
    ENABLED_MODULES="${ENABLED_MODULES//  / }"
    config_save

    log_success "Module '$module' removed from enabled modules"
}

# Show help
cmd_help() {
    cat << 'EOF'
Forgexx - Mac Configuration Sync via GitHub

USAGE:
  forgexx <command> [arguments]

COMMANDS:
  init <repo>        Initialize forgexx with a GitHub repository
  backup             Backup configurations to GitHub
  restore            Restore configurations from GitHub
  status             Show current status
  pull               Pull changes from GitHub
  push               Push changes to GitHub
  add <module>       Add a module to enabled modules
  remove <module>    Remove a module from enabled modules
  modules            List all available modules
  help               Show this help message

EXAMPLES:
  # Initialize with your GitHub repository
  forgexx init git@github.com:username/dotfiles.git

  # Backup your current configuration
  forgexx backup

  # Restore configuration on a new machine
  forgexx restore

  # See what would be backed up
  forgexx status

  # Add a module
  forgexx add vscode

CONFIGURATION:
  Config file: ~/.forgexx/config
  Repo directory: ~/.forgexx/home

  Environment variables:
    FORGEXX_CONFIG_DIR    - Override config directory
    FORGEXX_CONFIG_FILE   - Override config file path
    FORGEXX_REPO_DIR      - Override repository directory
    FORGEXX_LOG_LEVEL     - Set log level (0-5)

MODULES:
  homebrew   - Homebrew packages and casks
  dotfiles   - Dotfiles using GNU stow
  vscode     - VS Code settings and extensions
  npm        - npm global packages

For more information, visit: https://github.com/woosley/forgexx
EOF
}
