# Claude Code 配置同步模块设计文档

**日期**: 2026-03-03
**作者**: Woosley & Claude
**状态**: 设计阶段

## 1. 概述

### 1.1 目标

为 Forgexx 添加 Claude Code 配置同步模块，实现：
- 配置文件同步（settings.json、CLAUDE.md）
- 插件清单管理（通过 claude 命令安装）
- 技能同步（自动检测 git 仓库和本地技能）
- 自定义命令同步

### 1.2 约束

- **不同步用户 session**：明确排除 sessions/、history.jsonl 等
- **安全性**：API tokens 使用占位符替换
- **简洁性**：只同步必要的清单，不备份 cache 目录

## 2. 架构设计

### 2.1 模块结构

创建 `lib/modules/claude.sh`，遵循 Forgexx 标准模块模式：

```zsh
module_register "claude" \
    "Sync Claude Code configuration, plugins, and skills" \
    "claude_backup" \
    "claude_restore" \
    "claude_status"
```

### 2.2 目录结构

```
~/.forgexx/home/claude/
├── settings.json.template           # 配置文件（带占位符）
├── CLAUDE.md                        # 全局配置
├── commands/                        # 自定义命令
│   └── *.md
├── plugins/
│   └── installed_plugins.json       # 清理后的插件清单
└── skills/
    ├── .git_repos.txt               # Git 仓库 URL 列表
    └── {skill-name}/                # 本地技能完整代码
```

### 2.3 设计原则

- **与源目录结构一致**：保持 ~/.claude 的目录层级
- **最小化存储**：只备份清单和配置，不备份 cache
- **智能检测**：自动识别 git 仓库和本地文件
- **用户友好**：交互式确认和冲突处理

## 3. 备份逻辑

### 3.1 配置文件备份

#### settings.json 处理
```zsh
claude_backup_settings() {
    # 读取 JSON，替换敏感值为占位符
    # API keys → {{CLAUDE_API_KEY_PLACEHOLDER}}
    # Endpoints → {{CLAUDE_API_ENDPOINT_PLACEHOLDER}}
    # 保留其他配置项
}
```

#### CLAUDE.md 和 commands/
```zsh
# 直接复制 CLAUDE.md
cp "$HOME/.claude/CLAUDE.md" "$repo_dir/claude/"

# 复制整个 commands/ 目录
cp -R "$HOME/.claude/commands" "$repo_dir/claude/"
```

### 3.2 插件清单备份

#### installed_plugins.json 清理

**原始格式**：
```json
{
  "plugins": {
    "superpowers@claude-plugins-official": [{
      "scope": "user",
      "installPath": "/Users/woosleyxu/.claude/plugins/cache/.../4.3.1",
      "version": "4.3.1",
      "gitCommitSha": "abc123"
    }]
  }
}
```

**清理后**：
```json
{
  "plugins": {
    "superpowers@claude-plugins-official": [{
      "scope": "user",
      "version": "4.3.1",
      "gitCommitSha": "abc123"
    }]
  }
}
```

**关键操作**：
- 移除 `installPath` 字段（包含用户特定的 home 目录路径）
- 保留 plugin name、version、gitCommitSha
- 保留 scope 和时间戳（可选）

### 3.3 技能备份

#### 智能检测策略

```zsh
for skill in "$HOME/.claude/skills"/*; do
    if [[ -L "$skill" ]]; then
        # 符号链接，检查是否指向 git repo
        local target=$(readlink "$skill")
        if is_git_repo "$target"; then
            local remote_url=$(git -C "$target" remote get-url origin)
            echo "$(basename $skill)|$remote_url" >> ".git_repos.txt"
        fi
    elif [[ -d "$skill" ]]; then
        # 普通目录，完整复制
        cp -R "$skill" "$repo_dir/claude/skills/"
    fi
done
```

#### .git_repos.txt 格式
```
revealjs|https://github.com/hakimel/reveal.js.git
another-skill|https://github.com/user/repo.git
```

## 4. 恢复逻辑

### 4.1 配置文件恢复

#### settings.json.template 处理流程

1. 扫描 template 文件中的所有 `{{.*_PLACEHOLDER}}`
2. 列出需要填入的配置项
3. 提供选项：
   - 交互式输入每个值
   - 打开编辑器手动修改
   - 跳过（保持占位符，稍后手动配置）

```zsh
claude_restore_settings() {
    if grep -q "{{.*_PLACEHOLDER}}" "$template"; then
        log_warning "发现配置占位符，需要手动填入真实值"
        # 显示占位符列表
        # 交互式输入或打开编辑器
    fi
    cp "$template" "$HOME/.claude/settings.json"
}
```

#### 冲突处理

```zsh
handle_conflict() {
    echo "检测到文件冲突：$local_file"
    echo ""
    echo "选项："
    echo "  1) 查看差异"
    echo "  2) 使用本地版本"
    echo "  3) 使用仓库版本（本地备份为 .bak）"
    echo "  4) 手动编辑"
    echo ""
    read -k1 choice
    # 处理用户选择
}
```

### 4.2 插件恢复

#### 从清单安装插件

```zsh
claude_restore_plugins() {
    local plugin_list="$repo_dir/claude/plugins/installed_plugins.json"

    # 解析 JSON，提取插件列表
    local plugins=($(jq -r '.plugins | keys[]' "$plugin_list"))

    log_info "发现 ${#plugins[@]} 个已安装的插件"
    log_info "插件列表："
    for plugin in "${plugins[@]}"; do
        echo "  - $plugin"
    done

    # 交互式确认
    if ! confirm "是否安装这些插件？"; then
        log_info "跳过插件安装"
        return 0
    fi

    # 逐个安装
    for plugin in "${plugins[@]}"; do
        log_info "正在安装 $plugin..."
        if claude plugin install "$plugin"; then
            log_success "已安装 $plugin"
        else
            log_error "安装 $plugin 失败"
        fi
    done
}
```

### 4.3 技能恢复

#### 从 .git_repos.txt 克隆

```zsh
while IFS='|' read -r skill_name repo_url; do
    local target="$HOME/.claude/skills/$skill_name"
    if [[ -e "$target" ]]; then
        log_warning "$skill_name 已存在，跳过"
        continue
    fi

    log_info "正在克隆 $skill_name..."
    git clone "$repo_url" "$target"
done < "$git_repos_file"
```

#### 复制本地技能

```zsh
local local_skill_count=0
for skill_dir in "$local_skills_dir"/*; do
    if [[ -d "$skill_dir" ]]; then
        local skill_name=$(basename "$skill_dir")
        if [[ "$skill_name" == ".git_repos.txt" ]]; then
            continue
        fi

        if [[ -e "$target_dir/$skill_name" ]]; then
            log_warning "本地技能 $skill_name 已存在，跳过"
            continue
        fi

        log_info "正在复制本地技能: $skill_name"
        cp -R "$skill_dir" "$target_dir/"
        log_success "已复制本地技能: $skill_name"
        ((local_skill_count++))
    fi
done

if [[ $local_skill_count -gt 0 ]]; then
    log_success "共复制 $local_skill_count 个本地技能"
fi
```

## 5. 状态显示

### 5.1 状态信息结构

```zsh
claude_status() {
    echo "=== Claude Code Configuration Status ==="
    echo ""
    echo "📄 Configuration Files:"
    check_file "Settings (template)"
    check_file "CLAUDE.md"
    check_dir "Commands"

    echo ""
    echo "🔌 Plugins:"
    # 显示插件数量和列表

    echo ""
    echo "🎯 Skills:"
    # Git 仓库技能数量
    # 本地技能数量和列表
}
```

## 6. 错误处理

### 6.1 依赖检查

必需工具：
- `claude` - Claude Code CLI
- `jq` - JSON 处理工具
- `git` - 版本控制

### 6.2 文件操作安全

- 源文件存在性检查
- 目标目录创建
- JSON 格式验证
- Git 操作重试机制

### 6.3 用户中断处理

```zsh
trap handle_interrupt INT
```

## 7. 测试策略

### 7.1 单元测试

- 占位符替换测试
- 插件清单清理测试
- JSON 处理测试

### 7.2 集成测试

- 完整备份流程测试
- 恢复流程测试
- 冲突处理测试

### 7.3 手动测试清单

**备份测试**：
- [ ] 正常配置的完整备份
- [ ] 缺少某些配置文件时的部分备份
- [ ] settings.json 包含 API key 时的占位符替换
- [ ] Git 仓库技能的 URL 提取
- [ ] 本地技能的完整复制

**恢复测试**：
- [ ] 新环境的完整恢复
- [ ] 文件已存在时的冲突处理
- [ ] 占位符的交互式输入
- [ ] 插件安装的交互式确认
- [ ] Git 技能的克隆
- [ ] 本地技能的复制

## 8. 实施计划

实施计划将在下一阶段通过 `superpowers:writing-plans` skill 创建详细步骤。

## 9. 风险和注意事项

### 9.1 安全性

- `settings.json.template` 包含占位符，需要确保用户理解如何填入真实值
- Git 仓库应为私有，避免泄露配置信息

### 9.2 兼容性

- 依赖 `claude` CLI 工具，需要确保版本兼容
- `jq` 工具需要在所有目标机器上安装

### 9.3 用户体验

- 首次恢复时可能需要较长时间（插件安装）
- 冲突处理需要用户参与，可能增加复杂度

## 10. 未来改进

- [ ] 支持部分恢复（只恢复配置、不安装插件）
- [ ] 支持配置文件合并策略
- [ ] 添加配置验证工具
- [ ] 支持插件版本锁定
- [ ] 添加备份历史查看功能
