# Claude Code Configuration Sync Module Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-step.

**Goal:** Create a Forgexx module to sync Claude Code configuration, plugins, and skills across multiple macOS machines.

**Architecture:** Create `lib/modules/claude.sh` following Forgexx's modular plugin system. The module will backup configuration files with sensitive data replaced by placeholders, clean plugin manifests of user-specific paths, intelligently detect git-based vs local skills, and provide interactive restore with conflict resolution.

**Tech Stack:** Zsh scripting, jq for JSON processing, Git for version control, Claude Code CLI for plugin management

**Development Branch:** `feature/claude-module`

**Important:**
- All development MUST be done on the `feature/claude-module` branch
- DO NOT merge to `main` automatically
- Wait for user review and manual merge approval
- User will handle the merge after completion

---

## Task 1: Create Module Skeleton

**Files:**
- Create: `lib/modules/claude.sh`

**Step 1: Create basic module file with registration**

```zsh
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
```

**Step 2: Verify file creation**

Run: `ls -la lib/modules/claude.sh`
Expected: File exists with executable permissions

**Step 3: Add to bin/forgexx loader**

Add to `bin/forgexx` after other module loads:

```zsh
# Load Claude module
if [[ -f "$LIB_DIR/modules/claude.sh" ]]; then
    source "$LIB_DIR/modules/claude.sh"
fi
```

**Step 4: Test module registration**

Run: `./bin/forgexx modules`
Expected: `claude` appears in module list with description

**Step 5: Commit**

```bash
git add lib/modules/claude.sh bin/forgexx
git commit -m "feat: add Claude module skeleton

- Register claude module with backup/restore/status functions
- Add dependency checking (claude, jq, git)
- Integrate into main loader

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 2: Implement Configuration Backup

**Files:**
- Modify: `lib/modules/claude.sh`

**Step 1: Implement config backup function**

Add after dependency check:

```zsh
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
    # This is a conservative approach - we remove fields that might contain API keys
    jq 'del(.apiKey, .apiKeys, .anthropicApiKey, .claudeApiKey)' "$source" > "$target"

    # Add placeholders for manual configuration
    local temp_file="${target}.tmp"
    jq '."
+ "  // 在此配置您的 Claude API Key"
+ "  // \"apiKey\": \"sk-ant-...\""
+ "}"' "$target" > "$temp_file" && mv "$temp_file" "$target"

    log_success "已创建配置模板（敏感信息已移除）"
}
```

**Step 2: Test config backup manually**

Run: `FORGEXX_CONFIG_DIR=/tmp/test_forgexx ./bin/forgexx backup`

Check: `ls -la ~/.forgexx/home/claude/`
Expected:
- `settings.json.template` exists
- `CLAUDE.md` exists (if present in source)
- `commands/` directory exists

**Step 3: Verify settings sanitization**

Run: `cat ~/.forgexx/home/claude/settings.json.template | jq`

Check: No `apiKey` or similar fields present

**Step 4: Commit**

```bash
git add lib/modules/claude.sh
git commit -m "feat: implement Claude config backup

- Backup CLAUDE.md and commands directory
- Sanitize settings.json by removing API keys
- Create template file with placeholder comments

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 3: Implement Plugin Manifest Backup

**Files:**
- Modify: `lib/modules/claude.sh`

**Step 1: Implement plugin backup function**

```zsh
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
```

**Step 2: Test plugin backup**

Run: `FORGEXX_CONFIG_DIR=/tmp/test_forgexx ./bin/forgexx backup`

Check: `cat ~/.forgexx/home/claude/plugins/installed_plugins.json | jq`

Verify: No `installPath` fields in the output

**Step 3: Commit**

```bash
git add lib/modules/claude.sh
git commit -m "feat: implement plugin manifest backup

- Read installed_plugins.json
- Remove installPath fields (user-specific paths)
- Keep plugin names, versions, and commit SHAs

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 4: Implement Skills Backup

**Files:**
- Modify: `lib/modules/claude.sh`

**Step 1: Implement skills backup function**

```zsh
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

    local git_repos_file="$skills_dir/.git_repos.txt"
    > "$git_repos_file"  # Empty the file

    local local_count=0
    local git_count=0

    for skill_path in "$source_dir"/*; do
        [[ -e "$skill_path" ]] || continue
        local skill_name=$(basename "$skill_path")

        if [[ -L "$skill_path" ]]; then
            # Symlink - check if it points to a git repo
            local target=$(readlink "$skill_path")
            if [[ -d "$target/.git" ]]; then
                local remote_url=$(git -C "$target" remote get-url origin 2>/dev/null || echo "")
                if [[ -n "$remote_url" ]]; then
                    echo "$skill_name|$remote_url" >> "$git_repos_file"
                    ((git_count++))
                    log_info "记录 git 仓库技能: $skill_name"
                fi
            fi
        elif [[ -d "$skill_path" ]]; then
            # Regular directory - copy entirely
            if [[ "$skill_name" != ".git"* ]]; then
                cp -R "$skill_path" "$skills_dir/"
                ((local_count++))
                log_info "复制本地技能: $skill_name"
            fi
        fi
    done

    if [[ $git_count -gt 0 ]]; then
        log_success "已记录 $git_count 个 git 仓库技能"
    fi

    if [[ $local_count -gt 0 ]]; then
        log_success "已复制 $local_count 个本地技能"
    fi

    # Remove .git_repos.txt if empty
    if [[ ! -s "$git_repos_file" ]]; then
        rm "$git_repos_file"
    fi
}
```

**Step 2: Test skills backup**

Run: `FORGEXX_CONFIG_DIR=/tmp/test_forgexx ./bin/forgexx backup`

Check: `ls -la ~/.forgexx/home/claude/skills/`
Expected:
- `.git_repos.txt` exists (if any git-based skills)
- Local skill directories copied

**Step 3: Verify git repos file**

Run: `cat ~/.forgexx/home/claude/skills/.git_repos.txt`
Expected: Format `skill_name|https://github.com/user/repo.git`

**Step 4: Commit**

```bash
git add lib/modules/claude.sh
git commit -m "feat: implement skills backup with intelligent detection

- Detect symlinks pointing to git repos, record URLs
- Copy local skill directories entirely
- Generate .git_repos.txt for git-based skills

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 5: Implement Configuration Restore

**Files:**
- Modify: `lib/modules/claude.sh`

**Step 1: Implement config restore function**

```zsh
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
```

**Step 2: Add helper function for confirm prompts**

```zsh
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
```

**Step 3: Test config restore in safe environment**

Run:
```bash
mkdir -p /tmp/test_claude_restore
cd /tmp/test_claude_restore
FORGEXX_CONFIG_DIR=/tmp/test_forgexx_restore ./bin/forgexx restore
```

**Step 4: Commit**

```bash
git add lib/modules/claude.sh
git commit -m "feat: implement configuration restore with conflict handling

- Restore CLAUDE.md and commands with conflict resolution
- Interactive menu: diff/keep-local/use-repo/edit/skip
- Prompt for settings.json configuration
- Add confirm() helper for user prompts

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 6: Implement Plugin Restore

**Files:**
- Modify: `lib/modules/claude.sh`

**Step 1: Implement plugin restore function**

```zsh
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
```

**Step 2: Test plugin restore (dry run)**

First, check what plugins would be installed:

Run: `jq '.plugins | keys[]' ~/.forgexx/home/claude/plugins/installed_plugins.json`

**Step 3: Commit**

```bash
git add lib/modules/claude.sh
git commit -m "feat: implement plugin restore with interactive confirmation

- Parse plugin manifest from backup
- Display plugin list with versions
- Prompt for confirmation before installation
- Install plugins using claude CLI
- Report success/failure summary

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 7: Implement Skills Restore

**Files:**
- Modify: `lib/modules/claude.sh`

**Step 1: Implement skills restore function**

```zsh
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
    local git_repos_file="$skills_dir/.git_repos.txt"
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
```

**Step 2: Test skills restore**

Run:
```bash
FORGEXX_CONFIG_DIR=/tmp/test_forgexx_restore ./bin/forgexx restore
```

Check: `ls -la ~/.claude/skills/`

**Step 3: Commit**

```bash
git add lib/modules/claude.sh
git commit -m "feat: implement skills restore

- Clone git-based skills from .git_repos.txt
- Copy local skill directories
- Skip if skill already exists
- Detailed logging for each operation

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 8: Implement Status Display

**Files:**
- Modify: `lib/modules/claude.sh`

**Step 1: Implement status check functions**

```zsh
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
        local cmd_count=$(find "$claude_dir/commands" -type f | wc -l)
        echo "  ✓ commands ($cmd_count 个文件)"
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

    local count=$(jq '.plugins | length' "$plugin_file")
    echo "  ✓ 已备份 $count 个插件"

    # Show plugin list
    jq -r '.plugins | keys[]' "$plugin_file" | while read plugin; do
        local version=$(jq -r ".plugins[\"$plugin\"][0].version" "$plugin_file")
        echo "    - $plugin (v$version)"
    done
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
    local git_repos_file="$skills_dir/.git_repos.txt"
    if [[ -f "$git_repos_file" ]]; then
        local git_count=$(wc -l < "$git_repos_file")
        echo "  ✓ Git 仓库技能: $git_count 个"

        while IFS='|' read -r skill_name repo_url; do
            [[ -z "$skill_name" ]] && continue
            echo "    - $skill_name"
        done < "$git_repos_file"
    fi

    # Local skills
    local local_skills=($(find "$skills_dir" -mindepth 1 -maxdepth 1 -type d ! -name ".git*" -exec basename {} \;))
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
```

**Step 2: Test status display**

Run: `./bin/forgexx status`

Expected output showing all backed up items

**Step 3: Commit**

```bash
git add lib/modules/claude.sh
git commit -m "feat: implement comprehensive status display

- Check and display configuration files
- List all plugins with versions
- Show git-based and local skills
- Clear visual indicators (✓/✗)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 9: Add Documentation

**Files:**
- Modify: `README.md`

**Step 1: Update README with Claude module**

Add to modules list in README.md:

```markdown
### Claude Code Module

The Claude module (`claude`) synchronizes Claude Code configuration across multiple macOS machines.

**What it backs up:**
- `CLAUDE.md` - Global configuration and working contract
- `commands/` - Custom command definitions
- `settings.json.template` - Configuration with API keys removed
- `plugins/installed_plugins.json` - Plugin manifest (user paths cleaned)
- `skills/` - Custom skills (git repos recorded as URLs, local skills copied)

**What it does NOT back up:**
- User sessions and history
- Plugin cache directories (auto-generated)
- Temporary files and caches

**Configuration:**
No additional configuration required. The module uses sensible defaults:

- Git-based skills: Detected automatically, only repo URLs stored
- Local skills: Copied entirely to repository
- Plugins: Only manifest stored, re-installed via `claude plugin install`

**Usage:**

```bash
# Enable the module
forgexx add claude

# Backup Claude Code configuration
forgexx backup

# Restore on new machine
forgexx restore

# Check status
forgexx status
```

**Manual Configuration Required:**
After restore, you'll need to manually configure API keys in `~/.claude/settings.json`.
```

**Step 2: Update module list in README**

Add `claude` to the modules list section.

**Step 3: Commit documentation**

```bash
git add README.md
git commit -m "docs: add Claude module documentation

- Describe what the claude module backs up
- Explain usage and configuration
- Note manual configuration requirements

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 10: Final Testing and Validation

**Files:**
- None (testing)

**Step 1: Perform full backup test**

Run: `./bin/forgexx backup`

Verify:
```bash
# Check directory structure
ls -la ~/.forgexx/home/claude/

# Verify settings sanitization
cat ~/.forgexx/home/claude/settings.json.template | jq

# Verify plugin manifest
cat ~/.forgexx/home/claude/plugins/installed_plugins.json | jq '.plugins[] | .[0] | keys'
# Should NOT contain "installPath"

# Check skills
cat ~/.forgexx/home/claude/skills/.git_repos.txt
ls -la ~/.forgexx/home/claude/skills/
```

**Step 2: Test status command**

Run: `./bin/forgexx status`

Verify all items show correctly

**Step 3: Create test restore environment**

```bash
# Create test environment
mkdir -p /tmp/claude_restore_test/.claude
export HOME=/tmp/claude_restore_test

# Run restore
cd /Users/woosleyxu/code/forgexx
./bin/forgexx restore
```

**Step 4: Verify restore**

```bash
# Check restored files
ls -la /tmp/claude_restore_test/.claude/

# Verify settings template exists
cat /tmp/claude_restore_test/.claude/settings.json

# Check skills
ls -la /tmp/claude_restore_test/.claude/skills/
```

**Step 5: Create final commit with any fixes**

```bash
git add -A
git commit -m "fix: address issues found during testing

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Completion Criteria

✅ Module registered and appears in `forgexx modules`
✅ Backup creates sanitized settings.json.template
✅ Backup removes installPath from plugin manifest
✅ Backup intelligently handles git vs local skills
✅ Restore provides interactive conflict resolution
✅ Restore installs plugins via claude CLI
✅ Restore clones git-based skills
✅ Restore copies local skills
✅ Status command shows all backed up items
✅ Documentation updated in README
✅ Full backup/restore cycle tested successfully

---

## Notes for Implementation

- **Security**: Never backup API keys or sensitive tokens
- **User Experience**: Always provide interactive confirmation for destructive operations
- **Idempotency**: Running backup/restore multiple times should be safe
- **Error Handling**: Gracefully handle missing files/directories
- **Logging**: Clear, actionable log messages at every step

## Related Documentation

- Design document: `docs/plans/2026-03-03-claude-module-design.md`
- Forgexx architecture: `CLAUDE.md`
- Module development: See existing modules in `lib/modules/`

---

## Post-Completion Actions

**After all tasks are completed:**

1. **DO NOT merge to main**
2. **Push feature branch to remote:**
   ```bash
   git push origin feature/claude-module
   ```
3. **Create pull request** (optional) or notify user
4. **Wait for user review and approval**
5. **User will handle merge manually:**
   ```bash
   git checkout main
   git pull origin main
   git merge feature/claude-module
   # Review and resolve any conflicts
   git push origin main
   ```

**Branch cleanup** (after successful merge):
```bash
git branch -d feature/claude-module
git push origin --delete feature/claude-module
```
