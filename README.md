# Forgexx

> Mac Configuration Sync via GitHub

Forgexx 是一个轻量级的工具，帮助你通过 GitHub 同步多台 Mac 之间的配置和软件。

## 特性

- **无数据库**：所有配置存储在 Git 仓库中，简单透明
- **无需直连**：两台 Mac 不需要在同一网络，通过 GitHub 中转
- **模块化设计**：支持 Homebrew、dotfiles、VSCode、npm 等多种配置
- **增量同步**：只同步变更的内容
- **声明式配置**：轻松添加自定义模块

## 安装

```bash
# 克隆仓库
git clone https://github.com/woosley/forgexx.git ~/forgexx

# 添加到 PATH
export PATH="$PATH:~/forgexx/bin"

# 或创建符号链接
ln -s ~/forgexx/bin/forgexx /usr/local/bin/forgexx
```

## 快速开始

### 1. 准备 GitHub 仓库

在 GitHub 上创建一个新仓库（可以是 private）用于存储配置：

```
git@github.com:yourusername/dotfiles.git
```

### 2. 初始化 Forgexx

在第一台 Mac 上运行：

```bash
forgexx init git@github.com:yourusername/dotfiles.git
```

这会：
- 创建 `~/.forgexx/` 配置目录
- 初始化本地 Git 仓库
- 生成配置文件

### 3. 备份配置

```bash
forgexx backup
```

这会备份：
- Homebrew 安装的包（Brewfile）
- dotfiles（.zshrc, .vimrc, .gitconfig 等）
- VSCode 扩展和设置
- npm 全局包

### 4. 推送到 GitHub

```bash
cd ~/.forgexx/home
git push -u origin main
```

### 5. 在第二台 Mac 上恢复

```bash
# 初始化（使用相同的仓库）
forgexx init git@github.com:yourusername/dotfiles.git

# 拉取配置
forgexx pull

# 恢复配置
forgexx restore
```

## 命令参考

```
forgexx <command> [arguments]

命令：
  init <repo>        初始化 Forgexx，指定 GitHub 仓库
  backup             备份配置到本地仓库
  restore            从本地仓库恢复配置
  status             查看当前状态
  pull               从 GitHub 拉取更新
  push               推送更新到 GitHub
  add <module>       添加模块
  remove <module>    移除模块
  modules            列出所有可用模块
  help               显示帮助
```

## 模块

### 内置模块

| 模块 | 描述 | 依赖 |
|------|------|------|
| `homebrew` | Homebrew 包和 cask | brew |
| `dotfiles` | Dotfiles（使用 GNU stow） | stow |
| `vscode` | VSCode 设置和扩展 | code |
| `npm` | npm 全局包 | npm |

### 配置模块

编辑 `~/.forgexx/config`：

```bash
# GitHub 仓库
GITHUB_REPO="git@github.com:yourusername/dotfiles.git"
LOCAL_REPO="$HOME/.forgexx/home"

# 启用的模块
ENABLED_MODULES="homebrew dotfiles vscode"
```

### Dotfiles 配置

默认同步的文件：
- `.zshrc`
- `.vimrc`
- `.tmux.conf`
- `.gitconfig`
- `.gitignore_global`

要自定义，编辑 `lib/modules/dotfiles.sh` 中的 `FORGEXX_DOTFILES` 变量。

## 工作流程

### 日常使用

```bash
# 在 Mac A 上做了配置更改
forgexx backup    # 备份到本地
forgexx push      # 推送到 GitHub

# 在 Mac B 上获取更新
forgexx pull      # 从 GitHub 拉取
forgexx restore   # 恢复配置
```

### 自动推送

配置 `~/.forgexx/config`：

```bash
# 备份后自动推送
export FORGEXX_AUTO_PUSH="true"
```

然后只需运行：

```bash
forgexx backup   # 自动备份 + 推送
```

## 目录结构

```
~/.forgexx/
├── config          # 配置文件
└── home/           # Git 仓库
    ├── .git/
    ├── homebrew/
    │   └── Brewfile
    ├── dotfiles/
    │   └── home/
    │       ├── .zshrc
    │       └── .vimrc
    ├── vscode/
    │   ├── settings.json
    │   └── extensions.txt
    └── npm/
        └── packages.txt
```

## 添加自定义模块

在 `lib/modules/` 创建新模块，例如 `custom.sh`：

```bash
#!/bin/bash
source "$(dirname "${BASH_SOURCE[0]}")/base.sh"

module_register "custom" \
    "My custom module" \
    "custom_backup" \
    "custom_restore" \
    "custom_status"

custom_backup() {
    local repo_dir=$1
    # 备份逻辑
    cp ~/.myconfig "$repo_dir/custom/"
}

custom_restore() {
    local repo_dir=$1
    # 恢复逻辑
    cp "$repo_dir/custom/.myconfig" ~/
}

custom_status() {
    echo "  Custom: OK"
}
```

然后在 `bin/forgexx` 中 source 它：

```bash
source "$LIB_DIR/modules/custom.sh"
```

## 与原 forge 工具的对比

| 特性 | forge | forgexx |
|------|-------|---------|
| 语言 | Shell | Bash (模块化) |
| 存储 | 本地 | GitHub |
| 同步方式 | 手动复制 | Git push/pull |
| 模块系统 | 简单 | 可扩展 |
| 冲突处理 | 无 | Git 原生支持 |
| 版本历史 | 无 | Git 完整历史 |

## 环境变量

- `FORGEXX_CONFIG_DIR` - 配置目录（默认：`~/.forgexx`）
- `FORGEXX_CONFIG_FILE` - 配置文件路径
- `FORGEXX_REPO_DIR` - 本地仓库路径
- `FORGEXX_LOG_LEVEL` - 日志级别 (0-5)

## 故障排查

### stow 失败

```bash
brew install stow
```

### 权限问题

```bash
chmod +x ~/forgexx/bin/forgexx
```

### Git 推送失败

检查 SSH 密钥配置：

```bash
ssh -T git@github.com
```

## License

MIT
