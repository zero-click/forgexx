#!/bin/zsh
# Claude Code configuration sync module

# Register the module
module_register "claude" \
    "Sync Claude Code configuration, plugins, and skills" \
    "claude_backup" \
    "claude_restore" \
    "claude_status"

# Backup function: System -> Repository
claude_backup() {
    local repo_dir=$1

    log_info "开始备份 Claude Code 配置..."

    # Check dependencies
    if ! claude_check_dependencies; then
        return 1
    fi

    # Backup configuration files
    claude_backup_config "$repo_dir"

    # Backup plugins manifest
    claude_backup_plugins "$repo_dir"

    # Backup skills
    claude_backup_skills "$repo_dir"

    log_success "Claude Code 配置备份完成"
}

# Restore function: Repository -> System
claude_restore() {
    local repo_dir=$1

    log_info "开始恢复 Claude Code 配置..."

    # Check dependencies
    if ! claude_check_dependencies; then
        return 1
    fi

    # Restore configuration files
    claude_restore_config "$repo_dir"

    # Restore plugins
    claude_restore_plugins "$repo_dir"

    # Restore skills
    claude_restore_skills "$repo_dir"

    log_success "Claude Code 配置恢复完成"
}

# Status function: Display current status
claude_status() {
    local repo_dir=$1

    echo ""
    echo "=== Claude Code Configuration Status ==="
    echo ""

    # Check config files
    echo "📄 Configuration Files:"
    claude_check_config "$repo_dir"

    # Check plugins
    echo ""
    echo "🔌 Plugins:"
    claude_check_plugins "$repo_dir"

    # Check skills
    echo ""
    echo "🎯 Skills:"
    claude_check_skills "$repo_dir"

    echo ""
}

# Check dependencies
claude_check_dependencies() {
    local missing_deps=()

    command_exists claude || missing_deps+=("claude")
    command_exists jq || missing_deps+=("jq")
    command_exists git || missing_deps+=("git")

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "缺少必需的依赖: ${missing_deps[*]}"
        log_info "请先安装缺少的依赖"
        return 1
    fi

    return 0
}
