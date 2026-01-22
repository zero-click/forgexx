#!/bin/zsh
# Configuration management for forgexx

# Default paths
FORGEXX_CONFIG_DIR="${FORGEXX_CONFIG_DIR:-$HOME/.forgexx}"
FORGEXX_CONFIG_FILE="${FORGEXX_CONFIG_FILE:-$FORGEXX_CONFIG_DIR/config}"
FORGEXX_REPO_DIR="${FORGEXX_REPO_DIR:-$FORGEXX_CONFIG_DIR/home}"

# Create config directory if it doesn't exist
ensure_config_dir() {
    if [[ ! -d "$FORGEXX_CONFIG_DIR" ]]; then
        mkdir -p "$FORGEXX_CONFIG_DIR"
    fi
}

# Load configuration from file
config_load() {
    if [[ -f "$FORGEXX_CONFIG_FILE" ]]; then
        source "$FORGEXX_CONFIG_FILE"
    fi
}

# Save configuration to file
config_save() {
    cat > "$FORGEXX_CONFIG_FILE" << EOF
# Forgexx Configuration
# Generated at $(date)

GITHUB_REPO="${GITHUB_REPO}"
LOCAL_REPO="${LOCAL_REPO}"
ENABLED_MODULES="${ENABLED_MODULES}"

EOF
}

# Initialize configuration
config_init() {
    local github_repo=$1

    ensure_config_dir

    GITHUB_REPO="$github_repo"
    LOCAL_REPO="${LOCAL_REPO:-$FORGEXX_REPO_DIR}"
    ENABLED_MODULES="${ENABLED_MODULES:-homebrew dotfiles vscode npm}"

    config_save
}

# Get configuration value (zsh indirect reference)
config_get() {
    local key=$1
    echo ${(P)key}
}

# Set configuration value
config_set() {
    local key=$1
    local value=$2
    export "$key=$value"
    config_save
}

# Check if a module is enabled
config_is_module_enabled() {
    local module=$1
    [[ " $ENABLED_MODULES " =~ " $module " ]]
}

# Validate configuration
config_validate() {
    if [[ -z "$GITHUB_REPO" ]]; then
        log_error "GitHub repository not configured. Run 'forgexx init <repo>' first."
        return 1
    fi

    return 0
}

# Print current configuration
config_print() {
    cat << EOF
Forgexx Configuration
=====================
GitHub Repo:    ${GITHUB_REPO:-<not set>}
Local Repo:    ${LOCAL_REPO:-$FORGEXX_REPO_DIR}
Enabled Modules:
$(for module in ${=ENABLED_MODULES}; do echo "  - $module"; done)
EOF
}

# Module-specific configuration
# Each module can define its own config functions
module_config_get() {
    local module=$1
    local key=$2
    var="FORGEXX_${module^^}_${key^^}"
    echo ${(P)var}
}

module_config_set() {
    local module=$1
    local key=$2
    local value=$3
    local var="FORGEXX_${module^^}_${key^^}"
    export "$var=$value"
}
