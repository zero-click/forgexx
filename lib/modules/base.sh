#!/bin/zsh
# Base module class for forgexx modules

# Module registration system
typeset -A FORGEXX_MODULE_BACKUP_FUNCS
typeset -A FORGEXX_MODULE_RESTORE_FUNCS
typeset -A FORGEXX_MODULE_STATUS_FUNCS
typeset -A FORGEXX_MODULE_DESCRIPTIONS

# Register a module
module_register() {
    local name=$1
    local description=$2
    local backup_func=${3:-"${name}_backup"}
    local restore_func=${4:-"${name}_restore"}
    local status_func=${5:-"${name}_status"}

    FORGEXX_MODULE_DESCRIPTIONS[$name]="$description"
    FORGEXX_MODULE_BACKUP_FUNCS[$name]="$backup_func"
    FORGEXX_MODULE_RESTORE_FUNCS[$name]="$restore_func"
    FORGEXX_MODULE_STATUS_FUNCS[$name]="$status_func"

    log_debug "Registered module: $name"
}

# Get module description
module_get_description() {
    local name=$1
    echo "${FORGEXX_MODULE_DESCRIPTIONS[$name]}"
}

# Check if module is registered
module_is_registered() {
    local name=$1
    [[ -n "${FORGEXX_MODULE_DESCRIPTIONS[$name]}" ]]
}

# List all registered modules
module_list_all() {
    for module in ${(k)FORGEXX_MODULE_DESCRIPTIONS}; do
        echo "  - $module: ${FORGEXX_MODULE_DESCRIPTIONS[$module]}"
    done
}

# Execute module backup
module_do_backup() {
    local name=$1
    local repo_dir=$2

    if ! module_is_registered "$name"; then
        log_error "Module '$name' is not registered"
        return 1
    fi

    local backup_func="${FORGEXX_MODULE_BACKUP_FUNCS[$name]}"

    log_step "$name" "Backing up..."
    if $backup_func "$repo_dir"; then
        log_success "$name backup completed"
        return 0
    else
        log_error "$name backup failed"
        return 1
    fi
}

# Execute module restore
module_do_restore() {
    local name=$1
    local repo_dir=$2

    if ! module_is_registered "$name"; then
        log_error "Module '$name' is not registered"
        return 1
    fi

    local restore_func="${FORGEXX_MODULE_RESTORE_FUNCS[$name]}"

    log_step "$name" "Restoring..."
    if $restore_func "$repo_dir"; then
        log_success "$name restore completed"
        return 0
    else
        log_error "$name restore failed"
        return 1
    fi
}

# Execute module status
module_do_status() {
    local name=$1
    local repo_dir=$2

    if ! module_is_registered "$name"; then
        log_error "Module '$name' is not registered"
        return 1
    fi

    local status_func="${FORGEXX_MODULE_STATUS_FUNCS[$name]}"
    $status_func "$repo_dir"
}

# Utility function to create safe symlinks
safe_symlink() {
    local source=$1
    local target=$2

    # Create source directory if it doesn't exist
    local source_dir=$(dirname "$source")
    mkdir -p "$source_dir"

    # Handle existing target
    if [[ -e "$target" ]]; then
        if [[ -L "$target" ]]; then
            # Already a symlink, remove it
            rm "$target"
        elif [[ -f "$target" || -d "$target" ]]; then
            # Real file or directory, back it up
            local backup="${target}.bak"
            mv "$target" "$backup"
            log_warning "Backed up existing $target to $backup"
        fi
    fi

    ln -s "$source" "$target"
    log_debug "Created symlink: $target -> $source"
}

# Utility function to backup a file to repo
backup_file() {
    local source=$1
    local target_dir=$2

    if [[ -f "$source" ]]; then
        mkdir -p "$target_dir"
        cp "$source" "$target_dir/"
        log_debug "Backed up: $source"
        return 0
    else
        log_debug "File not found: $source"
        return 1
    fi
}

# Utility function to restore a file from repo
restore_file() {
    local source=$1
    local target=$2

    if [[ -f "$source" ]]; then
        mkdir -p "$(dirname "$target")"
        cp "$source" "$target"
        log_debug "Restored: $target"
        return 0
    else
        log_warning "Source not found: $source"
        return 1
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" &>/dev/null
}

# Ensure command is available
require_command() {
    local cmd=$1
    local package=${2:-$cmd}

    if ! command_exists "$cmd"; then
        log_error "Required command '$cmd' not found."
        log_info "Install it with: brew install $package"
        return 1
    fi
    return 0
}
