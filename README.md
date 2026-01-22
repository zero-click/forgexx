# Forgexx

> Mac 配置同步工具 (Mac Configuration Sync via GitHub)

Forgexx 是一个轻量级、模块化的 CLI 工具，旨在通过 GitHub 在多台 macOS 设备之间同步配置、软件和开发环境。

## 核心特性

- **纯 Shell 编写**：基于 Zsh 编写，无重依赖，轻量高效。
- **模块化设计**：按需启用不同模块（Homebrew, Dotfiles, VSCode 等）。
- **Git 驱动**：所有配置存储在本地 Git 仓库，自动同步到 GitHub，版本可追溯。
- **直连复制**：Dotfiles 采用直接复制（Direct Copy）模式，简单粗暴但有效，无需学习 GNU Stow。
- **安全**：SSH 模块只同步公钥和非敏感配置，绝不触碰私钥。

## 安装

### 方法 1: 克隆并配置

```zsh
# 克隆仓库
git clone https://github.com/woosley/forgexx.git ~/forgexx

# 添加到 PATH (建议添加到 .zshrc)
export PATH="$PATH:~/forgexx/bin"

# 或者创建软链接
ln -s ~/forgexx/bin/forgexx /usr/local/bin/forgexx
```

### 方法 2: 依赖检查

确保你的系统已安装 `git` 和 `zsh`（macOS 默认已安装）。

## 快速开始

### 1. 准备

在 GitHub 上创建一个空仓库（推荐设为 Private 私有仓库），例如 `my-mac-config`。

### 2. 初始化

在第一台电脑上：

```zsh
# 初始化并绑定远程仓库
forgexx init git@github.com:username/my-mac-config.git
```

### 3. 配置模块

编辑配置文件 `~/.forgexx/config` 来选择你要启用的模块：

```zsh
# 默认启用 homebrew, dotfiles, vscode, npm
# 你可以添加 git, ssh, iterm2 等
export ENABLED_MODULES="homebrew dotfiles vscode git iterm2 npm ssh"
```

### 4. 备份与同步

```zsh
# 备份当前配置到本地仓库
forgexx backup

# 如果配置了 FORGEXX_AUTO_PUSH=true，backup 会自动推送。
# 否则手动推送：
forgexx push
```

### 5. 在新电脑恢复

```zsh
# 1. 初始化
forgexx init git@github.com:username/my-mac-config.git

# 2. 拉取配置
forgexx pull

# 3. 恢复配置
forgexx restore
```

## 模块详解

Forgexx 目前内置以下模块：

| 模块 | 描述 | 备份内容 |
|------|------|----------|
| **base** | 核心模块 | (基础功能，不直接产生备份文件) |
| **homebrew** | 包管理器 | 生成 `Brewfile` (包含 Taps, Brews, Casks, Mas) |
| **dotfiles** | 配置文件 | 默认同步 `.zshrc`, `.vimrc`, `.tmux.conf` 等 (可配置) |
| **vscode** | 编辑器 | `settings.json` 和 `extensions.txt` (插件列表) |
| **npm** | Node.js | 全局安装的 npm 包列表 |
| **git** | Git 配置 | `.gitconfig` 和 `.gitignore_global` |
| **ssh** | SSH | `~/.ssh/config` 和所有公钥 (`*.pub`)。**不备份私钥**。 |
| **iterm2** | 终端 | iTerm2 配置文件 (`com.googlecode.iterm2.plist`) |

### Dotfiles 高级配置

你可以在 `~/.forgexx/config` 中自定义要同步的文件和目录：

```zsh
# 自定义要同步的文件 (相对 $HOME)
export FORGEXX_DOTFILES=".zshrc .bash_profile .vimrc .config/starship.toml"

# 自定义要同步的目录
export FORGEXX_DOTDIRS=".config/nvim .config/alacritty"
```

## 目录结构

Forggex 将所有数据保存在 `~/.forgexx/`：

```text
~/.forgexx/
├── config              # Forgexx 自身的配置文件
└── home/               # 本地 Git 仓库 (实际同步的内容)
    ├── .git/
    ├── homebrew/       # homebrew 模块数据
    ├── dotfiles/       # dotfiles 模块数据
    ├── vscode/         # vscode 模块数据
    ├── git/            # git 模块数据
    └── ...
```

## 命令参考

```text
forgexx init <repo>     初始化并绑定 GitHub 仓库
forgexx backup          执行备份 (System -> Repo)
forgexx restore         执行恢复 (Repo -> System)
forgexx pull            从 GitHub 拉取最新配置
forgexx push            推送本地配置到 GitHub
forgexx status          查看配置状态和模块状态
forgexx list            列出所有可用模块
forgexx add <module>    启用指定模块
forgexx remove <module> 禁用指定模块
```

## 环境变量

你可以在 `~/.zshrc` 或 `~/.bashrc` 中设置：

- `FORGEXX_CONFIG_DIR`: 自定义配置目录 (默认: `~/.forgexx`)
- `FORGEXX_AUTO_PUSH`: 设置为 `true` 可在 backup 后自动 push
- `FORGEXX_COMMIT_MSG`: 自定义备份时的 Commit 信息模板

## 常见问题

**Q: Dotfiles 模块和 Git 模块冲突吗？**
A: 默认情况下，`dotfiles` 模块也会尝试备份 `.gitconfig`。如果同时启用，后运行的模块会覆盖前一个。建议在 `FORGEXX_DOTFILES` 中移除 `.gitconfig` 如果你启用了 `git` 模块，或者只使用 `dotfiles` 模块来管理一切。

**Q: 如何恢复 iTerm2 配置？**
A: 运行 `forgexx restore` 后，你可能需要重启 iTerm2 才能看到效果。

## License

MIT