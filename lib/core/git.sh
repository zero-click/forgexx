#!/bin/zsh
# Git operations for forgexx

# Initialize a new git repository
git_init() {
    local repo_dir=$1
    local remote_url=$2

    log_info "Initializing git repository in $repo_dir"

    if [[ ! -d "$repo_dir" ]]; then
        mkdir -p "$repo_dir"
    fi

    cd "$repo_dir" || return 1

    if [[ ! -d ".git" ]]; then
        git init
        log_success "Git repository initialized"
    else
        log_info "Git repository already exists"
    fi

    # Add remote if provided
    if [[ -n "$remote_url" ]]; then
        if git remote get-url origin &>/dev/null; then
            git remote set-url origin "$remote_url"
            log_info "Updated remote origin"
        else
            git remote add origin "$remote_url"
            log_success "Added remote origin"
        fi
    fi

    # Create initial structure
    mkdir -p homebrew dotfiles vscode npm macos

    # Create .gitignore
    cat > .gitignore << 'EOF'
# OS generated files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# Sensitive files (encrypt these manually if needed)
.env
.secrets
*.key
*.pem

# Temporary files
*.tmp
*.swp
*~
EOF

    git add .gitignore
    git commit -m "Initial commit" &>/dev/null || true

    return 0
}

# Clone an existing repository
git_clone() {
    local remote_url=$1
    local repo_dir=$2

    log_info "Cloning repository from $remote_url"

    if [[ -d "$repo_dir" ]]; then
        log_warning "Directory $repo_dir already exists"
        return 1
    fi

    git clone "$remote_url" "$repo_dir"
    cd "$repo_dir" || return 1

    log_success "Repository cloned successfully"
    return 0
}

# Stage all changes
git_stage_all() {
    local repo_dir=$1

    cd "$repo_dir" || return 1

    log_info "Staging changes..."
    git add -A
}

# Commit changes
git_commit() {
    local repo_dir=$1
    local message=$2

    cd "$repo_dir" || return 1

    # Check if there are changes to commit
    if git diff --cached --quiet && git diff --quiet; then
        log_info "No changes to commit"
        return 0
    fi

    # Expand variables in message
    local hostname=$(hostname -s)
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    local expanded_message="${message//\{\{hostname\}\}/$hostname}"
    expanded_message="${expanded_message//\{\{timestamp\}\}/$timestamp}"

    git commit -m "$expanded_message"
    log_success "Changes committed"
}

# Push to remote
git_push() {
    local repo_dir=$1
    local branch=${2:-main}

    cd "$repo_dir" || return 1

    log_info "Pushing to origin/$branch..."

    if git push origin "$branch" 2>&1; then
        log_success "Pushed successfully"
        return 0
    else
        log_error "Failed to push"
        return 1
    fi
}

# Pull from remote
git_pull() {
    local repo_dir=$1
    local branch=${2:-main}

    cd "$repo_dir" || return 1

    log_info "Pulling from origin/$branch..."

    if git pull origin "$branch" 2>&1; then
        log_success "Pulled successfully"
        return 0
    else
        log_error "Failed to pull"
        return 1
    fi
}

# Check if there are uncommitted changes
git_has_changes() {
    local repo_dir=$1

    cd "$repo_dir" || return 1

    ! git diff --quiet && ! git diff --cached --quiet
}

# Get current branch
git_current_branch() {
    local repo_dir=$1

    cd "$repo_dir" || return 1

    git rev-parse --abbrev-ref HEAD
}

# Sync: pull, then stage, commit, and push
git_sync() {
    local repo_dir=$1
    local message=${2:-"Update configs"}
    local auto_push=${3:-false}
    local branch=${4:-main}

    # Pull first to get latest changes
    if ! git_pull "$repo_dir" "$branch"; then
        log_warning "Failed to pull, continuing anyway..."
    fi

    # Stage changes
    git_stage_all "$repo_dir"

    # Commit
    git_commit "$repo_dir" "$message"

    # Push if requested
    if [[ "$auto_push" == "true" ]]; then
        git_push "$repo_dir" "$branch"
    fi
}

# Show git status
git_status() {
    local repo_dir=$1

    cd "$repo_dir" || return 1

    echo
    echo "=== Git Status ==="
    git status -sb
    echo
    echo "=== Recent Commits ==="
    git log --oneline -5
}
