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

# Backup configuration files
claude_backup_config() {
    local repo_dir=$1
    local claude_dir="$repo_dir/claude"

    # Create directory structure
    mkdir -p "$claude_dir/commands"

    # Backup CLAUDE.md
    if [[ -f "$HOME/.claude/CLAUDE.md" ]]; then
        log_info "备份 CLAUDE.md"
        cp "$HOME/.claude/CLAUDE.md" "$claude_dir/"
    else
        log_warning "未找到 CLAUDE.md，跳过"
    fi

    # Backup commands directory
    if [[ -d "$HOME/.claude/commands" ]]; then
        log_info "备份 commands 目录"
        cp -R "$HOME/.claude/commands/"* "$claude_dir/commands/" 2>/dev/null || true
    else
        log_warning "未找到 commands 目录，跳过"
    fi

    # Backup and sanitize settings.json
    if [[ -f "$HOME/.claude/settings.json" ]]; then
        log_info "备份 settings.json（替换敏感信息）"
        claude_sanitize_settings "$HOME/.claude/settings.json" "$claude_dir/settings.json.template"
    else
        log_warning "未找到 settings.json，跳过"
    fi
}

# Sanitize settings.json by replacing sensitive values with placeholders
claude_sanitize_settings() {
    local source=$1
    local target=$2

    # Use jq to remove sensitive fields
    # This removes API keys from root level and from env object
    jq 'del(.apiKey, .apiKeys, .anthropicApiKey, .claudeApiKey, .env.ANTHROPIC_AUTH_TOKEN, .env.ANTHROPIC_API_KEY, .env.CLAUDE_API_KEY)' "$source" > "$target"

    # Add a comment at the end for manual configuration
    # Note: JSON doesn't support comments, so we add a marker field
    local temp_file="${target}.tmp"
    jq '. + {"_comment": "在此配置您的 Claude API Key: apiKey: sk-ant-..."}' "$target" > "$temp_file" && mv "$temp_file" "$target"

    log_success "已创建配置模板（敏感信息已移除）"
}

# Backup plugins manifest
claude_backup_plugins() {
    local repo_dir=$1
    local plugins_dir="$repo_dir/claude/plugins"

    # Create plugins directory
    mkdir -p "$plugins_dir"

    local source_manifest="$HOME/.claude/plugins/installed_plugins.json"

    if [[ ! -f "$source_manifest" ]]; then
        log_warning "未找到插件清单，跳过"
        return 0
    fi

    log_info "清理插件清单（移除用户特定路径）"

    # Remove installPath field which contains user-specific home directory
    jq 'del(.plugins[][].installPath)' "$source_manifest" > "$plugins_dir/installed_plugins.json"

    local plugin_count=$(jq '.plugins | length' "$plugins_dir/installed_plugins.json")
    log_success "已备份 $plugin_count 个插件清单"
}

# Stub: Backup skills (Task 5)
claude_backup_skills() {
    local repo_dir=$1
    log_warning "技能备份功能尚未实现"
}

# Stub: Restore configuration (Task 9)
claude_restore_config() {
    local repo_dir=$1
    log_warning "配置恢复功能尚未实现"
}

# Stub: Restore plugins (Task 3)
claude_restore_plugins() {
    local repo_dir=$1
    log_warning "插件恢复功能尚未实现"
}

# Stub: Restore skills (Task 6)
claude_restore_skills() {
    local repo_dir=$1
    log_warning "技能恢复功能尚未实现"
}

# Stub: Check config status (Task 10)
claude_check_config() {
    local repo_dir=$1
    local claude_dir="$repo_dir/claude"

    if [[ -f "$claude_dir/CLAUDE.md" ]]; then
        echo "  ✓ CLAUDE.md"
    else
        echo "  ✗ CLAUDE.md (未备份)"
    fi

    if [[ -f "$claude_dir/settings.json.template" ]]; then
        echo "  ✓ settings.json.template"
    else
        echo "  ✗ settings.json.template (未备份)"
    fi

    if [[ -d "$claude_dir/commands" ]] && [[ -n "$(ls -A $claude_dir/commands 2>/dev/null)" ]]; then
        echo "  ✓ commands/"
    else
        echo "  ✗ commands/ (未备份或为空)"
    fi
}

# Stub: Check plugins status (Task 10)
claude_check_plugins() {
    local repo_dir=$1
    echo "  插件状态检查尚未实现"
}

# Stub: Check skills status (Task 10)
claude_check_skills() {
    local repo_dir=$1
    echo "  技能状态检查尚未实现"
}
