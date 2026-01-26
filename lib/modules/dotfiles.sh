#!/bin/zsh
# Dotfiles module for forgexx

# Register the dotfiles module
module_register "dotfiles" \
    "Dotfiles (direct copy)" \
    "dotfiles_backup" \
    "dotfiles_restore" \
    "dotfiles_status"

# Default dotfiles to sync
FORGEXX_DOTFILES="${FORGEXX_DOTFILES:-.gitconfig .gitignore_global}"
FORGEXX_DOTDIRS="${FORGEXX_DOTDIRS:-.config/nvim .config/alacritty}"

# Backup dotfiles
dotfiles_backup() {
    local repo_dir=$1
    local dotfiles_dir="$repo_dir/dotfiles"

    mkdir -p "$dotfiles_dir"

    log_info "Backing up dotfiles..."

    # Backup individual files (use -L to follow symlinks and copy actual content)
    for file in ${=FORGEXX_DOTFILES}; do
        local source="$HOME/$file"
        local target="$dotfiles_dir/$file"

        if [[ -e "$source" ]]; then
            mkdir -p "$(dirname "$target")"
            # Use -L to dereference symlinks and copy actual file content
            cp -RL "$source" "$target"
            log_debug "Backed up: $file"
        else
            log_debug "Not found: $file"
        fi
    done

    # Backup directories
    for dir in ${=FORGEXX_DOTDIRS}; do
        local source="$HOME/$dir"
        local target="$dotfiles_dir/$dir"

        if [[ -d "$source" ]]; then
            mkdir -p "$(dirname "$target")"
            cp -RL "$source" "$target"
            log_debug "Backed up: $dir"
        else
            log_debug "Not found: $dir"
        fi
    done

    log_success "Dotfiles backed up to $dotfiles_dir"
    return 0
}

# Restore dotfiles (direct copy, will overwrite existing files)
dotfiles_restore() {
    local repo_dir=$1
    local dotfiles_dir="$repo_dir/dotfiles"

    if [[ ! -d "$dotfiles_dir" ]]; then
        log_warning "Dotfiles directory not found: $dotfiles_dir"
        return 1
    fi

    log_info "Restoring dotfiles..."

    # Restore files
    local restored=0
    for file in $(find "$dotfiles_dir" -type f -o -type l); do
        local relative_path="${file#$dotfiles_dir/}"
        local target="$HOME/$relative_path"

        # Backup existing file if it exists
        if [[ -e "$target" && ! -L "$target" ]]; then
            local backup_path="${target}.forgexx.bak"
            mv "$target" "$backup_path"
            log_warning "Backed up existing $target to $backup_path"
        fi

        # Create target directory
        mkdir -p "$(dirname "$target")"

        # Copy file
        cp -R "$file" "$target"
        log_debug "Restored: $relative_path"
        ((restored++))
    done

    log_success "Restored $restored dotfile(s)"
    return 0
}

# Show dotfiles status
dotfiles_status() {
    local repo_dir=$1
    local dotfiles_dir="$repo_dir/dotfiles"

    echo "  Dotfiles:"
    if [[ -d "$dotfiles_dir" ]]; then
        local file_count=$(find "$dotfiles_dir" -type f 2>/dev/null | wc -l | tr -d ' ')
        echo "    Status: $file_count files in backup"
    else
        echo "    Status: No dotfiles in repo"
    fi
}
