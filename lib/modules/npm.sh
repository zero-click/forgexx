#!/bin/zsh
# npm module for forgexx

# Register the npm module
module_register "npm" \
    "npm global packages" \
    "npm_backup" \
    "npm_restore" \
    "npm_status"

# Backup npm global packages
npm_backup() {
    local repo_dir=$1
    local npm_dir="$repo_dir/npm"

    mkdir -p "$npm_dir"

    if ! command_exists npm; then
        log_warning "npm not installed, skipping..."
        return 0
    fi

    log_info "Backing up npm global packages..."

    # Get list of globally installed packages
    npm list -g --depth=0 --json > "$npm_dir/packages.json"

    # Also create a simple text list
    npm list -g --depth=0 --parseable | tail -n +2 | xargs basename -a 2>/dev/null > "$npm_dir/packages.txt"

    log_success "npm packages backed up to $npm_dir"
    return 0
}

# Restore npm global packages
npm_restore() {
    local repo_dir=$1
    local npm_dir="$repo_dir/npm"

    if ! command_exists npm; then
        log_warning "npm not installed, skipping..."
        return 0
    fi

    if [[ ! -f "$npm_dir/packages.txt" ]]; then
        log_warning "No npm packages backup found"
        return 1
    fi

    log_info "Restoring npm global packages..."

    local count=0
    while IFS= read -r package; do
        if [[ -n "$package" ]]; then
            log_debug "Installing: $package"
            if npm install -g "$package" &>/dev/null; then
                ((count++))
            else
                log_warning "Failed to install: $package"
            fi
        fi
    done < "$npm_dir/packages.txt"

    log_success "Installed $count npm packages"
    return 0
}

# Show npm status
npm_status() {
    local repo_dir=$1
    local npm_dir="$repo_dir/npm"

    echo "  npm:"
    if command_exists npm; then
        echo "    Status: Installed ($(npm --version))"
        if [[ -f "$npm_dir/packages.txt" ]]; then
            local count=$(wc -l < "$npm_dir/packages.txt" | tr -d ' ')
            echo "    Packages: $count in backup"
        else
            echo "    Packages: No backup found"
        fi
    else
        echo "    Status: Not installed"
    fi
}
