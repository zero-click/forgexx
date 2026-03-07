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

    # Backup marketplaces manifest
    claude_backup_marketplaces "$repo_dir"

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

    # Restore marketplaces (插件源)
    claude_restore_marketplaces "$repo_dir"

    # Restore plugins (依赖 marketplaces)
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

    # Check marketplaces
    echo ""
    echo "🏪 Marketplaces:"
    claude_check_marketplaces "$repo_dir"

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

# Backup marketplaces manifest
claude_backup_marketplaces() {
    local repo_dir=$1
    local marketplaces_dir="$repo_dir/claude/marketplaces"
    local source_dir="$HOME/.claude/plugins/marketplaces"

    if [[ ! -d "$source_dir" ]]; then
        log_warning "未找到 marketplaces 目录，跳过"
        return 0
    fi

    mkdir -p "$marketplaces_dir"
    local git_repos_file="$marketplaces_dir/git_repos.txt"
    : > "$git_repos_file"  # Empty the file

    local git_count=0

    for marketplace_path in "$source_dir"/*; do
        [[ -e "$marketplace_path" ]] || continue
        local marketplace_name=$(basename "$marketplace_path")

        # Skip hidden directories
        [[ "$marketplace_name" == ".git"* ]] && continue

        # Check if it's a git repository
        local git_dir=$(git -C "$marketplace_path" rev-parse --git-dir 2>/dev/null || echo "")

        if [[ -n "$git_dir" ]]; then
            # Get the remote URL
            local remote_url=$(git -C "$marketplace_path" remote get-url origin 2>/dev/null || echo "")
            if [[ -n "$remote_url" ]]; then
                echo "$marketplace_name|$remote_url" >> "$git_repos_file"
                ((git_count++))
                log_info "记录 marketplace: $marketplace_name"
            else
                log_warning "marketplace $marketplace_name 没有 origin remote，跳过"
            fi
        fi
    done

    if [[ $git_count -gt 0 ]]; then
        log_success "已记录 $git_count 个 marketplace"
    fi

    # Remove git_repos.txt if empty
    if [[ ! -s "$git_repos_file" ]]; then
        rm "$git_repos_file"
    fi
}

# Backup skills
claude_backup_skills() {
    local repo_dir=$1
    local skills_dir="$repo_dir/claude/skills"
    local source_dir="$HOME/.claude/skills"

    if [[ ! -d "$source_dir" ]]; then
        log_warning "未找到 skills 目录，跳过"
        return 0
    fi

    mkdir -p "$skills_dir"

    local git_repos_file="$skills_dir/git_repos.txt"
    : > "$git_repos_file"  # Empty the file

    local local_count=0
    local git_count=0

    for skill_path in "$source_dir"/*; do
        [[ -e "$skill_path" ]] || continue
        local skill_name=$(basename "$skill_path")

        # Skip hidden directories
        [[ "$skill_name" == ".git"* ]] && continue

        # Check if it's a git repository (works with symlinks, worktrees, regular repos)
        local git_dir=$(git -C "$skill_path" rev-parse --git-dir 2>/dev/null || echo "")

        if [[ -n "$git_dir" ]]; then
            # It's a git repo - get the remote URL
            local remote_url=$(git -C "$skill_path" remote get-url origin 2>/dev/null || echo "")
            if [[ -n "$remote_url" ]]; then
                echo "$skill_name|$remote_url" >> "$git_repos_file"
                ((git_count++))
                log_info "记录 git 仓库技能: $skill_name"
            else
                log_warning "git 仓库技能 $skill_name 没有 origin remote，跳过"
            fi
        elif [[ -d "$skill_path" ]]; then
            # Local directory (not a git repo) - copy entirely
            cp -R "$skill_path" "$skills_dir/"
            ((local_count++))
            log_info "复制本地技能: $skill_name"
        fi
    done

    if [[ $git_count -gt 0 ]]; then
        log_success "已记录 $git_count 个 git 仓库技能"
    fi

    if [[ $local_count -gt 0 ]]; then
        log_success "已复制 $local_count 个本地技能"
    fi

    # Remove git_repos.txt if empty
    if [[ ! -s "$git_repos_file" ]]; then
        rm "$git_repos_file"
    fi
}

# Restore configuration files
claude_restore_config() {
    local repo_dir=$1
    local claude_dir="$repo_dir/claude"

    if [[ ! -d "$claude_dir" ]]; then
        log_warning "未找到 Claude 配置备份"
        return 0
    fi

    # Restore CLAUDE.md
    if [[ -f "$claude_dir/CLAUDE.md" ]]; then
        if [[ -f "$HOME/.claude/CLAUDE.md" ]]; then
            if ! claude_handle_conflict "$HOME/.claude/CLAUDE.md" "$claude_dir/CLAUDE.md"; then
                log_info "跳过 CLAUDE.md"
            fi
        else
            log_info "恢复 CLAUDE.md"
            mkdir -p "$HOME/.claude"
            cp "$claude_dir/CLAUDE.md" "$HOME/.claude/"
            log_success "已恢复 CLAUDE.md"
        fi
    fi

    # Restore commands
    if [[ -d "$claude_dir/commands" ]]; then
        mkdir -p "$HOME/.claude/commands"
        cp -R "$claude_dir/commands/"* "$HOME/.claude/commands/" 2>/dev/null || true
        log_success "已恢复 commands 目录"
    fi

    # Restore settings.json template
    if [[ -f "$claude_dir/settings.json.template" ]]; then
        log_info "发现 settings.json.template"
        log_warning "请手动配置 API keys 和其他敏感信息"
        echo ""
        echo "配置文件位置: $claude_dir/settings.json.template"
        echo "目标位置: \$HOME/.claude/settings.json"
        echo ""
        echo "建议操作："
        echo "  1. 编辑配置文件填入真实值"
        echo "  2. 复制到 \$HOME/.claude/settings.json"
        echo ""

        if confirm "是否现在创建配置文件？"; then
            mkdir -p "$HOME/.claude"
            cp "$claude_dir/settings.json.template" "$HOME/.claude/settings.json"
            log_success "已创建配置文件，请编辑填入真实值"
            ${EDITOR:-vi} "$HOME/.claude/settings.json"
        fi
    fi
}

# Restore marketplaces
claude_restore_marketplaces() {
    local repo_dir=$1
    local marketplaces_dir="$repo_dir/claude/marketplaces"

    # Check if backup exists
    local git_repos_file="$marketplaces_dir/git_repos.txt"
    if [[ ! -f "$git_repos_file" ]]; then
        log_warning "未找到 marketplace 清单，跳过"
        return 0
    fi

    log_info "发现 marketplace 清单"

    local success=0
    local failed=0

    while IFS='|' read -r marketplace_name repo_url; do
        [[ -z "$marketplace_name" ]] && continue

        log_info "正在添加 marketplace $marketplace_name..."

        # Use claude plugin marketplace add command instead of git clone
        if claude plugin marketplace add "$repo_url" 2>&1 | while read line; do
            echo "  $line"
        done; then
            log_success "已添加 $marketplace_name"
            ((success++))
        else
            log_error "添加 $marketplace_name 失败"
            ((failed++))
        fi
    done < "$git_repos_file"

    echo ""
    log_info "marketplace 恢复完成: 成功 $success, 失败 $failed"

    if [[ $success -gt 0 ]]; then
        log_success "共添加 $success 个 marketplace"
    fi
}

# Restore plugins
claude_restore_plugins() {
    local repo_dir=$1
    local plugin_manifest="$repo_dir/claude/plugins/installed_plugins.json"

    if [[ ! -f "$plugin_manifest" ]]; then
        log_warning "未找到插件清单，跳过"
        return 0
    fi

    log_info "发现插件清单"

    # Parse and display plugins
    local plugins=($(jq -r '.plugins | keys[]' "$plugin_manifest"))
    local plugin_count=${#plugins[@]}

    if [[ $plugin_count -eq 0 ]]; then
        log_info "没有需要安装的插件"
        return 0
    fi

    log_info "共 $plugin_count 个插件："
    for plugin in "${plugins[@]}"; do
        local version=$(jq -r ".plugins[\"$plugin\"][0].version" "$plugin_manifest")
        echo "  - $plugin (版本: $version)"
    done
    echo ""

    # Confirm installation
    if ! confirm "是否安装这些插件？"; then
        log_info "跳过插件安装"
        return 0
    fi

    # Install plugins
    local success_count=0
    local fail_count=0

    for plugin in "${plugins[@]}"; do
        log_info "正在安装 $plugin..."

        if claude plugin install "$plugin" 2>&1 | while read line; do
            echo "  $line"
        done; then
            log_success "已安装 $plugin"
            ((success_count++))
        else
            log_error "安装 $plugin 失败"
            ((fail_count++))
        fi
    done

    echo ""
    log_info "插件安装完成: 成功 $success_count, 失败 $fail_count"
}

# Restore skills
claude_restore_skills() {
    local repo_dir=$1
    local skills_dir="$repo_dir/claude/skills"

    if [[ ! -d "$skills_dir" ]]; then
        log_warning "未找到技能备份，跳过"
        return 0
    fi

    local target_dir="$HOME/.claude/skills"
    mkdir -p "$target_dir"

    # Restore git-based skills
    local git_repos_file="$skills_dir/git_repos.txt"
    if [[ -f "$git_repos_file" ]]; then
        log_info "发现 git 仓库技能清单"

        local git_count=0
        while IFS='|' read -r skill_name repo_url; do
            [[ -z "$skill_name" ]] && continue

            local target="$target_dir/$skill_name"

            if [[ -e "$target" ]]; then
                log_warning "$skill_name 已存在，跳过"
                continue
            fi

            log_info "正在克隆 $skill_name 从 $repo_url"

            if git clone "$repo_url" "$target" 2>&1; then
                log_success "已克隆 $skill_name"
                ((git_count++))
            else
                log_error "克隆 $skill_name 失败"
            fi
        done < "$git_repos_file"

        [[ $git_count -gt 0 ]] && log_success "共克隆 $git_count 个 git 仓库技能"
    fi

    # Restore local skills
    local local_count=0
    for skill_dir in "$skills_dir"/*; do
        [[ -d "$skill_dir" ]] || continue

        local skill_name=$(basename "$skill_dir")
        [[ "$skill_name" == ".git"* ]] && continue

        if [[ -e "$target_dir/$skill_name" ]]; then
            log_warning "本地技能 $skill_name 已存在，跳过"
            continue
        fi

        log_info "正在复制本地技能: $skill_name"
        cp -R "$skill_dir" "$target_dir/"

        if [[ $? -eq 0 ]]; then
            log_success "已复制本地技能: $skill_name"
            ((local_count++))
        else
            log_error "复制本地技能 $skill_name 失败"
        fi
    done

    [[ $local_count -gt 0 ]] && log_success "共复制 $local_count 个本地技能"
}

# Handle file conflicts
claude_handle_conflict() {
    local local_file=$1
    local repo_file=$2

    echo ""
    log_warning "检测到文件冲突: $local_file"
    echo ""
    echo "请选择操作："
    echo "  1) 查看差异 (diff)"
    echo "  2) 使用本地版本 (保留当前文件)"
    echo "  3) 使用仓库版本 (本地文件备份为 .bak)"
    echo "  4) 手动编辑"
    echo "  5) 跳过"
    echo ""
    echo -n "选择 [1-5]: "

    read -k1 choice
    echo ""

    case $choice in
        1)
            diff "$local_file" "$repo_file" | less
            claude_handle_conflict "$local_file" "$repo_file"
            ;;
        2)
            log_info "保留本地版本"
            return 1
            ;;
        3)
            cp "$local_file" "${local_file}.bak"
            cp "$repo_file" "$local_file"
            log_success "已使用仓库版本，本地文件备份为 ${local_file}.bak"
            return 0
            ;;
        4)
            ${EDITOR:-vi} "$local_file"
            return 0
            ;;
        5)
            log_info "跳过"
            return 1
            ;;
        *)
            log_error "无效选择"
            return 1
            ;;
    esac
}

# Ask user for confirmation
confirm() {
    local prompt="$1"
    local default="${2:-n}"

    if [[ $default == "y" ]]; then
        prompt="$prompt [Y/n]"
    else
        prompt="$prompt [y/N]"
    fi

    echo -n "$prompt "
    read -k1 answer
    echo ""

    if [[ -z "$answer" ]]; then
        [[ $default == "y" ]]
    else
        [[ $answer =~ ^[Yy]$ ]]
    fi
}

# Check configuration files status
claude_check_config() {
    local repo_dir=$1
    local claude_dir="$repo_dir/claude"

    if [[ ! -d "$claude_dir" ]]; then
        echo "  ✗ 未找到备份"
        return
    fi

    [[ -f "$claude_dir/settings.json.template" ]] && echo "  ✓ settings.json.template"
    [[ -f "$claude_dir/CLAUDE.md" ]] && echo "  ✓ CLAUDE.md"

    if [[ -d "$claude_dir/commands" ]]; then
        local cmd_count=$(find "$claude_dir/commands" -type f 2>/dev/null | wc -l | tr -d ' ')
        if [[ $cmd_count -gt 0 ]]; then
            echo "  ✓ commands ($cmd_count 个文件)"
        else
            echo "  ✗ commands (未备份)"
        fi
    else
        echo "  ✗ commands (未备份)"
    fi
}

# Check plugins status
claude_check_plugins() {
    local repo_dir=$1
    local plugin_file="$repo_dir/claude/plugins/installed_plugins.json"

    if [[ ! -f "$plugin_file" ]]; then
        echo "  ✗ 未找到插件清单"
        return
    fi

    local count=$(jq '.plugins | length' "$plugin_file" 2>/dev/null || echo "0")
    echo "  ✓ 已备份 $count 个插件"

    # Show plugin list
    jq -r '.plugins | keys[]' "$plugin_file" 2>/dev/null | while read plugin; do
        [[ -z "$plugin" ]] && continue
        local version=$(jq -r ".plugins[\"$plugin\"][0].version" "$plugin_file" 2>/dev/null || echo "unknown")
        echo "    - $plugin (v$version)"
    done
}

# Check marketplaces status
claude_check_marketplaces() {
    local repo_dir=$1
    local marketplaces_dir="$repo_dir/claude/marketplaces"

    if [[ ! -d "$marketplaces_dir" ]]; then
        echo "  ✗ 未找到 marketplace 备份"
        return
    fi

    local git_repos_file="$marketplaces_dir/git_repos.txt"
    if [[ ! -f "$git_repos_file" ]]; then
        echo "  ✗ 未找到 marketplace 清单"
        return
    fi

    local count=$(wc -l < "$git_repos_file" 2>/dev/null | tr -d ' ')
    echo "  ✓ 已备份 $count 个 marketplace"

    # Show marketplace list and installation status
    while IFS='|' read -r marketplace_name repo_url; do
        [[ -z "$marketplace_name" ]] && continue
        if [[ -d "$HOME/.claude/plugins/marketplaces/$marketplace_name" ]]; then
            echo "    ✓ $marketplace_name"
        else
            echo "    ✗ $marketplace_name [未安装]"
        fi
    done < "$git_repos_file"
}

# Check skills status
claude_check_skills() {
    local repo_dir=$1
    local skills_dir="$repo_dir/claude/skills"

    if [[ ! -d "$skills_dir" ]]; then
        echo "  ✗ 未找到技能备份"
        return
    fi

    # Git-based skills
    local git_repos_file="$skills_dir/git_repos.txt"
    if [[ -f "$git_repos_file" ]]; then
        local git_count=$(wc -l < "$git_repos_file" 2>/dev/null | tr -d ' ')
        echo "  ✓ Git 仓库技能: $git_count 个"

        while IFS='|' read -r skill_name repo_url; do
            [[ -z "$skill_name" ]] && continue
            echo "    - $skill_name"
        done < "$git_repos_file"
    fi

    # Local skills
    local local_skills=($(find "$skills_dir" -mindepth 1 -maxdepth 1 -type d ! -name ".git*" -exec basename {} \; 2>/dev/null))
    if [[ ${#local_skills[@]} -gt 0 ]]; then
        echo "  ✓ 本地技能: ${#local_skills[@]} 个"
        for skill in "${local_skills[@]}"; do
            echo "    - $skill"
        done
    fi

    # No skills found
    if [[ ! -f "$git_repos_file" ]] && [[ ${#local_skills[@]} -eq 0 ]]; then
        echo "  ✗ 未找到技能备份"
    fi
}
