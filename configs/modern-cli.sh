#!/usr/bin/env bash
#
# modern-cli.sh - Modern CLI Tool Aliases
#
# Installed to /etc/profile.d/modern-cli.sh by Ultimate Linux Suite
# Provides transparent aliases from classic to modern CLI tools
#
# To disable, remove this file or rename to .bak extension
#

# Only run for interactive shells
[[ $- == *i* ]] || return 0

# ============================================================================
# File Listing: ls -> eza
# ============================================================================
if command -v eza &>/dev/null; then
    alias ls='eza --icons --group-directories-first'
    alias ll='eza -l --icons --group-directories-first'
    alias la='eza -la --icons --group-directories-first'
    alias lt='eza --tree --icons --level=2'
    alias l='eza -l --icons'
fi

# ============================================================================
# File Viewing: cat -> bat
# ============================================================================
if command -v bat &>/dev/null; then
    alias cat='bat --style=plain --paging=never'
    alias less='bat --paging=always'
    # Keep original cat available as 'rawcat'
    alias rawcat='/usr/bin/cat'
fi

# ============================================================================
# File Finding: find -> fd
# ============================================================================
# fd is installed as 'fd' on most distros, 'fdfind' on Debian/Ubuntu
if command -v fd &>/dev/null; then
    # fd is already available
    :
elif command -v fdfind &>/dev/null; then
    alias fd='fdfind'
fi

# ============================================================================
# Text Searching: grep -> ripgrep
# ============================================================================
if command -v rg &>/dev/null; then
    alias grep='rg --color=auto'
    # Keep original grep available
    alias grepo='/usr/bin/grep --color=auto'
fi

# ============================================================================
# Disk Usage: du -> dust
# ============================================================================
if command -v dust &>/dev/null; then
    alias du='dust'
    # Keep original du available
    alias duo='/usr/bin/du'
fi

# ============================================================================
# Process Viewer: top -> btop
# ============================================================================
if command -v btop &>/dev/null; then
    alias top='btop'
    alias htop='btop'  # Also replace htop if btop is available
elif command -v htop &>/dev/null; then
    alias top='htop'
fi

# ============================================================================
# Directory Navigation: cd -> zoxide
# ============================================================================
if command -v zoxide &>/dev/null; then
    # Initialize zoxide for the current shell
    eval "$(zoxide init bash)"
    # Use 'z' for smart jumping, 'cd' stays as cd for compatibility
    # Users can manually use 'z' for smart navigation
fi

# ============================================================================
# JSON Processing
# ============================================================================
if command -v jq &>/dev/null; then
    # Pretty print JSON files
    json() { jq '.' "$@"; }
fi

if command -v yq &>/dev/null; then
    # Pretty print YAML files
    yaml() { yq '.' "$@"; }
fi

# ============================================================================
# Man Pages: man -> tldr
# ============================================================================
if command -v tldr &>/dev/null; then
    # tldr provides quick examples, keep man for full docs
    alias help='tldr'
    alias tl='tldr'
fi

# ============================================================================
# Git Improvements
# ============================================================================
if command -v delta &>/dev/null; then
    # delta is configured in ~/.gitconfig, just verify it's available
    :
fi

if command -v lazygit &>/dev/null; then
    alias lg='lazygit'
fi

# ============================================================================
# Modern Alternatives Summary
# ============================================================================
# The following modern tools are recommended by Ultimate Linux Suite:
#
# | Classic | Modern    | Description                        |
# |---------|-----------|-----------------------------------|
# | ls      | eza       | Modern ls with icons and git      |
# | cat     | bat       | Cat with syntax highlighting      |
# | find    | fd        | Simple, fast find alternative     |
# | grep    | ripgrep   | Blazingly fast recursive search   |
# | du      | dust      | Intuitive disk usage              |
# | top     | btop      | Beautiful resource monitor        |
# | cd      | zoxide    | Smart directory jumping           |
# | man     | tldr      | Simplified man pages              |
# | diff    | delta     | Beautiful git diffs               |
# | ps      | procs     | Modern process viewer             |
#
# These aliases provide transparent upgrades where available.
# Original commands are still accessible with 'o' suffix (e.g., 'grepo')
