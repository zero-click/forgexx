#!/bin/zsh
# iTerm2 module for forgexx

ITERM2_PREFS="$HOME/Library/Preferences/com.googlecode.iterm2.plist"

# Register the iterm2 module
module_register "iterm2" \
    "iTerm2 preferences" \
    "iterm2_backup" \
    "iterm2_restore" \
    "iterm2_status"

# Backup iTerm2 preferences
iterm2_backup() {
    local repo_dir=$1
    local iterm_dir="$repo_dir/iterm2"
    mkdir -p "$iterm_dir"

    if [[ -f "$ITERM2_PREFS" ]]; then
        cp "$ITERM2_PREFS" "$iterm_dir/"
        log_success "iTerm2 preferences backed up"
    else
        log_warning "iTerm2 preferences not found"
    fi

    return 0
}

# Restore iTerm2 preferences
iterm2_restore() {
    local repo_dir=$1
    local iterm_dir="$repo_dir/iterm2"

    if [[ -f "$iterm_dir/com.googlecode.iterm2.plist" ]]; then
        mkdir -p "$(dirname "$ITERM2_PREFS")"
        cp "$iterm_dir/com.googlecode.iterm2.plist" "$ITERM2_PREFS"
        log_success "iTerm2 preferences restored"
        log_warning "Please restart iTerm2 for changes to take effect"
    else
        log_warning "iTerm2 backup not found"
        return 1
    fi

    return 0
}

# Show iTerm2 status
iterm2_status() {
    echo "  iTerm2:"
    if [[ -f "$ITERM2_PREFS" ]]; then
        echo "    Status: Installed"
    else
        echo "    Status: Not installed"
    fi
}
