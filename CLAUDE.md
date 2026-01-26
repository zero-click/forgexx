# CLAUDE.md

本文件为 Claude Code (claude.ai/code) 在此仓库中工作时提供指导。

## 项目概述

**Forgexx** 是一个纯 Zsh CLI 工具，用于通过 GitHub 在多台 macOS 设备之间同步配置。它采用模块化架构，每个功能（Homebrew、dotfiles、VSCode 等）都作为独立模块实现，用户可以启用/禁用。

## 架构设计

### 模块系统

核心架构基于 `lib/modules/base.sh` 中定义的注册式模块系统：

- **模块注册**：每个模块调用 `module_register()`，传入名称、描述和三个函数指针（backup、restore、status）
- **模块存储**：函数指针存储在 Zsh 关联数组中：`FORGEXX_MODULE_BACKUP_FUNCS`、`FORGEXX_MODULE_RESTORE_FUNCS`、`FORGEXX_MODULE_STATUS_FUNCS`
- **执行流程**：核心命令遍历已启用的模块，通过存储的函数指针调用相应功能

### 模块实现模式

每个模块必须遵循以下结构：

```zsh
#!/bin/zsh
# Forgexx 模块描述

# 注册模块
module_register "modulename" \
    "人类可读的描述" \
    "modulename_backup" \
    "modulename_restore" \
    "modulename_status"

# 备份函数：系统 -> 仓库
modulename_backup() {
    local repo_dir=$1
    # 实现代码
}

# 恢复函数：仓库 -> 系统
modulename_restore() {
    local repo_dir=$1
    # 实现代码
}

# 状态函数：显示当前状态
modulename_status() {
    local repo_dir=$1
    # 实现代码
}
```

### 核心库

位于 `lib/core/` 目录：

- **base.sh**：模块注册系统、文件操作工具函数（`backup_file`、`restore_file`、`safe_symlink`）、命令检查
- **config.sh**：使用环境变量进行配置管理，支持 `FORGEXX_CONFIG_DIR`，通过 `FORGEXX_{MODULE}_{KEY}` 模式配置模块
- **commands.sh**：主命令处理器（init、backup、restore、status、pull、push、add、remove、modules）
- **git.sh**：本地仓库的 Git 操作封装
- **logger.sh**：彩色日志工具，包含日志级别（DEBUG=0、INFO=1、SUCCESS=2、WARNING=3、ERROR=4）

### 入口文件

`bin/forgexx` 是主可执行文件：
1. 加载核心库（logger 最先加载！）
2. 加载 base 模块
3. 加载所有功能模块
4. 解析命令并分发到 `commands.sh` 中的相应处理器

## 目录结构

```
~/.forgexx/                    # FORGEXX_CONFIG_DIR（可配置）
├── config                      # Zsh 配置文件（GITHUB_REPO、ENABLED_MODULES 等）
└── home/                       # FORGEXX_REPO_DIR（本地 Git 仓库）
    ├── .git/
    ├── homebrew/               # brew bundle dump 生成的 Brewfile
    ├── dotfiles/               # 配置文件的直接副本
    ├── vscode/                 # settings.json、extensions.txt、snippets/
    ├── npm/                    # 全局 npm 包列表
    ├── git/                    # .gitconfig、.gitignore_global
    ├── ssh/                    # config、*.pub 公钥（不含私钥）
    ├── iterm2/                 # com.googlecode.iterm2.plist
    ├── tmux/                   # .tmux.conf 配置文件
    ├── vim/                    # .vimrc 配置文件
    └── zsh/                    # .zshrc 配置文件
```

## 开发命令

### 运行工具

```bash
# 添加到 PATH 用于开发
export PATH="$PATH:/Users/woosleyxu/code/forgexx/bin"

# 直接运行
./bin/forgexx <command>

# 测试帮助命令
forgexx help
```

### 添加新模块

1. 创建 `lib/modules/yourmodule.sh`
2. 遵循上述模块实现模式
3. 在 `bin/forgexx` 中加载该模块（在其他模块之后）
4. 通过 `forgexx add yourmodule` 即可启用

### 模块特定配置

用户可以通过环境变量配置模块，遵循 `FORGEXX_{MODULE}_{KEY}` 模式：

```zsh
# 在 ~/.forgexx/config 或环境变量中
export FORGEXX_DOTFILES=".zshrc .vimrc"
export FORGEXX_DOTDIRS=".config/nvim .config/alacritty"
```

模块中通过 `config.sh` 的 `module_config_get` 和 `module_config_set` 访问。

## 关键实现细节

### Vim 模块

Vim 模块提供了完整的配置和插件管理功能：

- **备份**：只备份 `~/.vimrc` 配置文件到仓库的 `vim/` 目录
- **还原**：
  1. 自动检查并安装 Vundle (Vim plugin manager) 到 `~/.vim/bundle/Vundle.vim`（如果尚未安装）
  2. 还原 `.vimrc` 配置文件（如果存在同名文件，先备份为 `.vimrc.bak`）
  3. 使用 Vundle 的 `PluginInstall` 命令自动安装配置的插件（运行 `vim +PluginInstall +qall`）
- **Vundle 安装路径**：`~/.vim/bundle/Vundle.vim`
- **Vundle 仓库**：`https://github.com/VundleVim/Vundle.vim.git`

注意：在 dotfiles 模块的默认配置中已移除 `.vimrc`，以避免与 vim 模块冲突。

### Tmux 模块

Tmux 模块提供了完整的配置和插件管理功能：

- **备份**：只备份 `~/.tmux.conf` 配置文件到仓库的 `tmux/` 目录
- **还原**：
  1. 自动检查并安装 TPM (Tmux Plugin Manager) 到 `~/.tmux/plugins/tpm`（如果尚未安装）
  2. 还原 `.tmux.conf` 配置文件（如果存在同名文件，先备份为 `.tmux.conf.bak`）
  3. 使用 TPM 的 `install_plugins` 脚本自动安装配置的插件
- **TPM 安装路径**：`~/.tmux/plugins/tpm`
- **TPM 仓库**：`https://github.com/tmux-plugins/tpm`

注意：在 dotfiles 模块的默认配置中已移除 `.tmux.conf`，以避免与 tmux 模块冲突。

### Zsh 模块

Zsh 模块提供了完整的配置和插件管理功能：

- **备份**：只备份 `~/.zshrc` 配置文件到仓库的 `zsh/` 目录
- **还原**：
  1. 自动检查并安装 oh-my-zsh 到 `~/.oh-my-zsh`（如果尚未安装）
  2. 自动检查并安装 zplug (Zsh plugin manager) 到 `~/.zplug`（如果尚未安装）
  3. 还原 `.zshrc` 配置文件（如果存在同名文件，先备份为 `.zshrc.bak`）
  4. 使用 zplug 的 `install` 命令自动安装配置的插件
- **oh-my-zsh 安装路径**：`~/.oh-my-zsh`
- **oh-my-zsh 仓库**：`https://github.com/ohmyzsh/ohmyzsh.git`
- **zplug 安装路径**：`~/.zplug`
- **zplug 仓库**：`https://github.com/zplug/zplug.git`

注意：在 dotfiles 模块的默认配置中已移除 `.zshrc`，以避免与 zsh 模块冲突。

### 文件复制策略

- **Dotfiles**：使用 `cp -RL`（跟随符号链接）直接复制，不创建符号链接
- **备份**：恢复前，现有文件会被备份为 `$file.bak`
- **安全**：SSH 模块只备份 `*.pub` 公钥文件，绝不处理私钥

### Zsh 特定语法

- `${0:a:h}` - 获取脚本目录（绝对路径的 dirname）
- `${(P)var}` - 间接引用（获取变量名为 $var 的变量的值）
- `${=VAR}` - 按空格分割变量为数组
- `${array[@]}` - 数组展开
- `${var^^}` - 转大写（bash 风格，zsh 中也支持）

### 错误处理

- 主脚本中使用 `set -e` - 任何错误时退出
- 模块成功返回 0，失败返回非零值
- 操作前使用 `command_exists()` 检查必需工具

### Git 工作流程

1. **本地仓库**：`~/.forgexx/home` 是一个 Git 仓库
2. **初始化**：创建仓库，从 `GITHUB_REPO` 变量添加远程仓库
3. **备份**：模块写入文件到仓库，执行 `git add` + `git commit`（可自定义提交信息）
4. **推送/拉取**：对远程仓库执行标准 git 操作
5. **自动推送**：如果设置 `FORGEXX_AUTO_PUSH=true`，备份后自动推送

## 测试变更

目前没有正式的测试套件。测试变更的方法：

1. 修改 `lib/` 或 `bin/` 中的代码
2. 直接运行命令：`forgexx <command>`
3. 检查 `~/.forgexx/home/` 中生成的文件
4. 使用 `forgexx status` 验证模块状态

## 环境变量

| 变量 | 默认值 | 用途 |
|----------|---------|---------|
| `FORGEXX_CONFIG_DIR` | `~/.forgexx` | 配置目录 |
| `FORGEXX_CONFIG_FILE` | `$FORGEXX_CONFIG_DIR/config` | 配置文件路径 |
| `FORGEXX_REPO_DIR` | `$FORGEXX_CONFIG_DIR/home` | 本地 Git 仓库 |
| `FORGEXX_AUTO_PUSH` | `false` | 备份后自动推送 |
| `FORGEXX_COMMIT_MSG` | 默认模板 | Git 提交信息 |
| `FORGEXX_LOG_LEVEL` | `1` (INFO) | 日志详细程度（0-5）|

## 模块列表

`lib/modules/` 中的当前模块：

- **homebrew.sh**：通过 `brew bundle dump` 生成 Brewfile
- **dotfiles.sh**：直接文件复制，可通过 `FORGEXX_DOTFILES` 和 `FORGEXX_DOTDIRS` 自定义
- **vscode.sh**：从 `~/Library/Application Support/Code/User/` 备份 `settings.json`、`extensions.txt`
- **npm.sh**：`npm list -g --depth=0` 的输出
- **git.sh**：`.gitconfig`、`.gitignore_global`
- **ssh.sh**：`.ssh/config` 和 `*.pub` 公钥（安全注意：绝不备份私钥）
- **iterm2.sh**：`~/Library/Preferences/com.googlecode.iterm2.plist`
- **tmux.sh**：`.tmux.conf` 配置文件和 TPM (Tmux Plugin Manager) 插件管理
- **vim.sh**：`.vimrc` 配置文件和 Vundle 插件管理
- **zsh.sh**：`.zshrc` 配置文件和 zplug 插件管理（依赖 oh-my-zsh）
