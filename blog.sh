#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VENV="$SCRIPT_DIR/.venv"
MKDOCS="$VENV/bin/mkdocs"

# ── global config (associative array) ──
declare -A CFG=(
    [src_dir]="src"
    [site_dir]="docs"
    [posts_dir]="src/blog/posts"
    [venv]="$VENV"
    [mkdocs]="$MKDOCS"
    [branch]="main"
    [remote]="origin"
)

# ── commands ──

cmd_build() {
    echo ":: building site"
    cd "$SCRIPT_DIR"
    "${CFG[mkdocs]}" build
    echo ":: done → ${CFG[site_dir]}/"
}

cmd_serve() {
    local drafts="${1:-on}"
    cd "$SCRIPT_DIR"

    case "$drafts" in
        on)
            echo ":: serving with drafts visible"
            DRAFTS=true "${CFG[mkdocs]}" serve
            ;;
        off)
            echo ":: serving without drafts (production preview)"
            DRAFTS=false "${CFG[mkdocs]}" serve
            ;;
        *)
            echo "usage: blog.sh serve [on|off]"
            return 1
            ;;
    esac
}

cmd_deploy() {
    echo ":: build + commit + push"
    cd "$SCRIPT_DIR"

    cmd_build

    local msg="${1:-update blog}"
    git add "${CFG[site_dir]}/" "${CFG[src_dir]}/" mkdocs.yml
    git commit -m "$msg" || { echo ":: nothing to commit"; return 0; }
    git push "${CFG[remote]}" "${CFG[branch]}"
    echo ":: pushed to ${CFG[remote]}/${CFG[branch]}"
}

cmd_new() {
    local title="${1:?usage: blog.sh new \"Post title\" [category]}"
    local category="${2:-General}"
    local slug date filepath

    date="$(date +%Y-%m-%d)"
    slug="$(echo "$title" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-')"
    filepath="${CFG[posts_dir]}/$date-$slug.md"

    if [[ -f "$SCRIPT_DIR/$filepath" ]]; then
        echo ":: already exists: $filepath"
        return 1
    fi

    cat > "$SCRIPT_DIR/$filepath" <<EOF
---
date: $date
authors:
  - bernardo
categories:
  - $category
draft: true
---

# $title

<!-- more -->
EOF

    echo ":: created $filepath"
}

cmd_help() {
    cat <<EOF
usage: blog.sh <command> [args]

commands:
  build              build site to ${CFG[site_dir]}/
  serve [on|off]     local preview (drafts on/off, default: on)
  deploy [msg]       build + commit + push (default msg: "update blog")
  new "title" [cat]  create a new post (default category: General)
  help               show this message

categories: General, Papers, Learning
EOF
}

# ── dispatch ──

main() {
    local cmd="${1:-help}"
    shift || true

    case "$cmd" in
        build)  cmd_build "$@" ;;
        serve)  cmd_serve "$@" ;;
        deploy) cmd_deploy "$@" ;;
        new)    cmd_new "$@" ;;
        help)   cmd_help ;;
        *)      echo "unknown command: $cmd"; cmd_help; exit 1 ;;
    esac
}

main "$@"
