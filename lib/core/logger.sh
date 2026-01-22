#!/bin/zsh
# Logging utilities for forgexx

# Colors
export COLOR_RED='\033[0;31m'
export COLOR_GREEN='\033[0;32m'
export COLOR_YELLOW='\033[1;33m'
export COLOR_BLUE='\033[0;34m'
export COLOR_PURPLE='\033[0;35m'
export COLOR_CYAN='\033[0;36m'
export COLOR_GRAY='\033[0;37m'
export COLOR_RESET='\033[0m'

# Log levels
export LOG_LEVEL_DEBUG=0
export LOG_LEVEL_INFO=1
export LOG_LEVEL_SUCCESS=2
export LOG_LEVEL_WARNING=3
export LOG_LEVEL_ERROR=4
export LOG_LEVEL_FATAL=5

# Current log level (default: INFO)
FORGEXX_LOG_LEVEL=${FORGEXX_LOG_LEVEL:-$LOG_LEVEL_INFO}

# Logging functions - always return 0 to avoid issues with set -e
log_debug() {
    [[ $FORGEXX_LOG_LEVEL -le $LOG_LEVEL_DEBUG ]] && echo -e "${COLOR_GRAY}[DEBUG]${COLOR_RESET} $*" >&2 || true
}

log_info() {
    [[ $FORGEXX_LOG_LEVEL -le $LOG_LEVEL_INFO ]] && echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $*" >&2 || true
}

log_success() {
    [[ $FORGEXX_LOG_LEVEL -le $LOG_LEVEL_SUCCESS ]] && echo -e "${COLOR_GREEN}[OK]${COLOR_RESET} $*" >&2 || true
}

log_warning() {
    [[ $FORGEXX_LOG_LEVEL -le $LOG_LEVEL_WARNING ]] && echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} $*" >&2 || true
}

log_error() {
    [[ $FORGEXX_LOG_LEVEL -le $LOG_LEVEL_ERROR ]] && echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $*" >&2 || true
}

log_fatal() {
    [[ $FORGEXX_LOG_LEVEL -le $LOG_LEVEL_FATAL ]] && echo -e "${COLOR_RED}[FATAL]${COLOR_RESET} $*" >&2 || true
    exit 1
}

# Progress indicators
log_step() {
    local step=$1
    shift
    echo -e "${COLOR_CYAN}[$step]${COLOR_RESET} $*"
}

# Spinner for long operations
spinner_start() {
    local message=$1
    local pid=$2

    local spin='-\|/'
    local i=0

    echo -ne "${COLOR_BLUE}$message${COLOR_RESET} "

    while kill -0 $pid 2>/dev/null; do
        i=$(( (i + 1) % 4 ))
        printf "\b${spin:$i:1}"
        sleep .1
    done

    echo -ne "\b"
}

# Confirm action
confirm() {
    local message=$1
    local default=${2:-n}

    local prompt
    if [[ $default == "y" ]]; then
        prompt="$message [Y/n] "
    else
        prompt="$message [y/N] "
    fi

    while true; do
        read -p "$prompt" -n 1 -r response
        echo
        response=${response:-$default}

        case "$response" in
            [Yy]|[Yy][Ee][Ss])
                return 0
                ;;
            [Nn]|[Nn][Oo])
                return 1
                ;;
            *)
                echo "Please answer yes or no."
                ;;
        esac
    done
}
