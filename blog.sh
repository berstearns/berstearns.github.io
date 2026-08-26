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
    [backlog]="BACKLOG.md"
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
    # new posts are private (zenitsu) by default; pass --public to opt out
    local private=true
    local path_only=false
    local tags=""
    local args=()
    local expect_tags=false
    for arg in "$@"; do
        if [[ "$expect_tags" == true ]]; then
            tags="$arg"; expect_tags=false; continue
        fi
        case "$arg" in
            --public) private=false ;;
            --path-only) path_only=true ;;   # print just the filepath (for editors)
            --tags) expect_tags=true ;;      # comma-separated: --tags "til,pytorch"
            --tags=*) tags="${arg#--tags=}" ;;
            *) args+=("$arg") ;;
        esac
    done

    local title="${args[0]:?usage: blog.sh new \"Post title\" [category] [--public]}"
    local category="${args[1]:-General}"
    local slug date filepath

    date="$(date +%Y-%m-%d)"
    slug="$(echo "$title" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-')"
    filepath="${CFG[posts_dir]}/$date-$slug.md"

    if [[ -f "$SCRIPT_DIR/$filepath" ]]; then
        # editors just want to open it; humans want to know it already existed
        [[ "$path_only" == true ]] && { echo "$filepath"; return 0; }
        echo ":: already exists: $filepath"
        return 1
    fi

    {
        echo "---"
        echo "date: $date"
        echo "authors:"
        echo "  - bernardo"
        echo "categories:"
        echo "  - $category"
        # tags only make sense on public posts: the build strips them from
        # private ones so the tag index never leaks a zenitsu URL
        if [[ -n "$tags" && "$private" != true ]]; then
            echo "tags:"
            echo "$tags" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;/^$/d;s/^/  - /'
        fi
        echo "draft: true"
        [[ "$private" == true ]] && echo "private: true"
        echo "---"
        echo ""
        echo "# $title"
        echo ""
        echo "<!-- more -->"
    } > "$SCRIPT_DIR/$filepath"

    if [[ "$path_only" == true ]]; then
        echo "$filepath"
    elif [[ "$private" == true ]]; then
        echo ":: created $filepath (private → /zenitsu/)"
    else
        echo ":: created $filepath (public)"
    fi
}

# ── post helpers ──

# _pick <candidates> <prompt> [target]
# Resolves one post path: grep-match on target, or fzf if target is empty.
# Prints the path on stdout; diagnostics go to stderr so callers can capture it.
_pick() {
    local candidates="$1" prompt="$2" target="${3:-}"

    if [[ -z "$candidates" ]]; then
        echo ":: no $prompt candidates found" >&2
        return 1
    fi

    if [[ -z "$target" ]]; then
        if ! command -v fzf >/dev/null; then
            echo ":: fzf not installed (pacman -S fzf)" >&2
            return 1
        fi
        local picked
        picked="$(echo "$candidates" | fzf --prompt="$prompt > " --height=40% --reverse)" || return 1
        [[ -z "$picked" ]] && { echo ":: cancelled" >&2; return 1; }
        echo "$picked"
        return 0
    fi

    local matches count
    matches="$(echo "$candidates" | grep -iF -- "$target" || true)"
    count="$(printf '%s\n' "$matches" | grep -c . || true)"

    if [[ "$count" -eq 0 ]]; then
        echo ":: no $prompt candidate matches '$target'" >&2
        echo ":: available:" >&2
        echo "$candidates" | sed 's|^|  |' >&2
        return 1
    elif [[ "$count" -gt 1 ]]; then
        echo ":: '$target' matches multiple, be more specific:" >&2
        echo "$matches" | sed 's|^|  |' >&2
        return 1
    fi

    echo "$matches"
}

_drafts()      { grep -l '^draft:[[:space:]]*[tT]rue[[:space:]]*$'   "${CFG[posts_dir]}"/*.md 2>/dev/null || true; }
_non_private() { grep -L '^private:[[:space:]]*[tT]rue[[:space:]]*$' "${CFG[posts_dir]}"/*.md 2>/dev/null || true; }

# Every post, newest first, tagged so the picker shows what you are about to
# touch. Private (zenitsu) posts are listed like any other -- they are ordinary
# files in posts_dir, only the `private: true` key sets them apart.
#   [zen]   private  -> unlisted, lives behind the gate at /zenitsu/
#   [drf]   draft    -> not published at all yet
_posts_annotated() {
    local f tag
    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        tag=""
        grep -q '^private:[[:space:]]*[tT]rue[[:space:]]*$' "$f" && tag+="[zen]" || tag+="     "
        grep -q '^draft:[[:space:]]*[tT]rue[[:space:]]*$'   "$f" && tag+="[drf]" || tag+="     "
        printf '%s %s\n' "$tag" "$f"
    done < <(ls -t "${CFG[posts_dir]}"/*.md 2>/dev/null)
}

# picker lines are "<tags> <path>" -- paths never contain spaces here
_path_of() { echo "${1##* }"; }

_undraft() {
    sed -i '/^draft:[[:space:]]*[tT]rue[[:space:]]*$/d' "$1"
}

_make_private() {
    local file="$1"
    grep -q '^private:[[:space:]]*[tT]rue[[:space:]]*$' "$file" && return 0
    # insert private: true after the draft line, else after the date line
    if grep -q '^draft:[[:space:]]*[tT]rue[[:space:]]*$' "$file"; then
        sed -i '/^draft:[[:space:]]*[tT]rue[[:space:]]*$/a private: true' "$file"
    else
        sed -i '0,/^date:/{/^date:/a private: true
}' "$file"
    fi
}

cmd_publish() {
    cd "$SCRIPT_DIR"
    local picked
    picked="$(_pick "$(_drafts)" "publish draft" "${1:-}")" || return $?
    _undraft "$picked"
    echo ":: published $picked"
}

cmd_zenitsu() {
    cd "$SCRIPT_DIR"
    local picked
    picked="$(_pick "$(_non_private)" "move to zenitsu" "${1:-}")" || return $?
    _make_private "$picked"
    echo ":: moved to zenitsu (private) → $picked"
}

# one-shot: mark a post private, drop its draft flag, build, commit, push
cmd_private_deploy() {
    cd "$SCRIPT_DIR"

    local picked
    picked="$(_pick "$(_posts_annotated)" "deploy as private" "${1:-}")" || return $?
    picked="$(_path_of "$picked")"

    _make_private "$picked"
    _undraft "$picked"
    echo ":: $picked → private, undrafted"

    cmd_build

    git add "${CFG[site_dir]}/" "${CFG[src_dir]}/" mkdocs.yml
    git commit -m "publish private post: $(basename "$picked" .md)" \
        || { echo ":: nothing to commit"; return 0; }
    git push "${CFG[remote]}" "${CFG[branch]}"
    echo ":: deployed (private) → /zenitsu/ on ${CFG[remote]}/${CFG[branch]}"
}

# ── daily zenitsu journal ──
# Two fixed private posts per day. Written in ~5 minutes, published on save.
# They are created WITHOUT `draft: true` so they go live immediately, and WITH
# `private: true` so they are unlisted and gated at /zenitsu/.
#   kind -> slug|heading|category
declare -A DAILY_KINDS=(
    [learned]="what-i-learned-today|What I learned today|Learning"
    [done]="what-i-have-done-today|What I have done today|General"
)

# Build + commit + push one or more files, serialized so the two daily panes
# (or a pane and the submit window) can publish at once without racing.
#   _publish <commit-msg> <file>...
_publish() {
    local msg="$1"; shift
    (
        flock -w 180 9 || { echo ":: timed out waiting for another publish to finish"; exit 1; }
        cmd_build
        git add "${CFG[site_dir]}/" "$@"
        if ! git commit -m "$msg"; then
            echo ":: nothing to commit"
            exit 0
        fi
        git push "${CFG[remote]}" "${CFG[branch]}"
    ) 9>"$SCRIPT_DIR/.git/blog-publish.lock"
}

# Today's daily files that actually exist, in a stable order.
_daily_files_today() {
    local today kind spec slug f
    today="$(date +%F)"
    for kind in learned done; do
        spec="${DAILY_KINDS[$kind]}"
        slug="${spec%%|*}"
        f="${CFG[posts_dir]}/${today}_${slug}.md"
        [[ -f "$f" ]] && echo "$f"
    done
}

# one line, end of day: both daily posts -> private -> live at /zenitsu/
cmd_submit_daily() {
    cd "$SCRIPT_DIR"

    local today files=()
    today="$(date +%F)"
    mapfile -t files < <(_daily_files_today)

    if [[ ${#files[@]} -eq 0 ]]; then
        echo ":: nothing written today"
        echo ":: start with:  ./blog.sh daily learned"
        return 0
    fi

    local f
    for f in "${files[@]}"; do
        _make_private "$f"
        _undraft "$f"
        # flag a file still sitting at the untouched template
        if [[ "$(grep -cv -e '^$' -e '^- $' "$f")" -le 12 ]] && ! grep -q '^- .\+' "$f"; then
            echo "   [empty]   $f"
        else
            echo "   [private] $f"
        fi
    done

    if [[ -z "$(git status --porcelain -- "${files[@]}")" ]]; then
        echo ":: already published and unchanged — nothing to do"
        return 0
    fi

    # a second run the same day is an edit, not a first publish -- say so, or
    # the history becomes a wall of identical "daily: <date>" lines
    local msg="daily: $today"
    for f in "${files[@]}"; do
        if git ls-files --error-unmatch "$f" >/dev/null 2>&1; then
            msg="daily: $today (update)"
            break
        fi
    done

    _publish "$msg" "${files[@]}"
    echo ":: submitted ${#files[@]} post(s) → /zenitsu/ — done for the day"
}

cmd_daily() {
    cd "$SCRIPT_DIR"

    local kind="" push=true
    for arg in "$@"; do
        case "$arg" in
            --no-push) push=false ;;
            *) kind="$arg" ;;
        esac
    done

    local spec="${DAILY_KINDS[$kind]:-}"
    if [[ -z "$spec" ]]; then
        echo "usage: blog.sh daily <learned|done> [--no-push]"
        return 1
    fi

    local slug heading category rest
    slug="${spec%%|*}"; rest="${spec#*|}"
    heading="${rest%%|*}"; category="${rest##*|}"

    local today file
    today="$(date +%F)"
    file="${CFG[posts_dir]}/${today}_${slug}.md"

    if [[ ! -f "$file" ]]; then
        {
            echo "---"
            echo "date: $today"
            echo "authors:"
            echo "  - bernardo"
            echo "categories:"
            echo "  - $category"
            echo "private: true"
            # explicit slug: the em dash in the heading would otherwise yield a
            # double-dashed URL (.../what-i-learned-today--2026-07-23/)
            echo "slug: ${slug}-${today}"
            echo "---"
            echo ""
            echo "# $heading — $today"
            echo ""
            echo "<!-- more -->"
            echo ""
            echo "- "
        } > "$file"
        echo ":: started $file"
    else
        echo ":: continuing $file"
    fi

    local before after
    before="$(md5sum < "$file")"
    "${EDITOR:-nvim}" "$file"
    after="$(md5sum < "$file")"

    if [[ "$before" == "$after" ]]; then
        echo ":: unchanged — nothing published today"
        return 0
    fi

    if [[ "$push" != true ]]; then
        echo ":: saved (--no-push) — publish later with: ./blog.sh deploy"
        return 0
    fi

    _publish "daily($kind): $today" "$file"
    echo ":: published → /zenitsu/ — done for the day"
}

# edit an already-published post and push the update
cmd_revise() {
    cd "$SCRIPT_DIR"

    local picked
    picked="$(_pick "$(_posts_annotated)" "revise post" "${1:-}")" || return $?
    picked="$(_path_of "$picked")"

    "${EDITOR:-nvim}" "$picked"

    if [[ -z "$(git status --porcelain -- "$picked")" ]]; then
        echo ":: no changes to $picked — nothing to push"
        return 0
    fi

    echo ""
    git --no-pager diff --stat -- "$picked" || true
    echo ""

    local ans
    read -r -p ":: rebuild + push this post? [y/N] " ans
    case "$ans" in
        y|Y|yes|YES) ;;
        *) echo ":: not pushed — your edits are still on disk"; return 0 ;;
    esac

    cmd_build
    git add "${CFG[site_dir]}/" "$picked"
    git commit -m "update post: $(basename "$picked" .md)" \
        || { echo ":: nothing to commit"; return 0; }
    git push "${CFG[remote]}" "${CFG[branch]}"
    echo ":: pushed → ${CFG[remote]}/${CFG[branch]}"
}

# ── idea backlog ──
# Lives OUTSIDE src/ so mkdocs never publishes it. One idea per line:
#   - [ ] 2026-07-22  the idea text
# Promoted ideas become "- [x] ... -> src/blog/posts/<file>.md".

_backlog_path() { echo "$SCRIPT_DIR/${CFG[backlog]}"; }

_backlog_init() {
    local f; f="$(_backlog_path)"
    [[ -f "$f" ]] && return 0
    {
        echo "# Blog idea backlog"
        echo ""
        echo "Unpublished scratch list. \`- [ ]\` = open, \`- [x]\` = promoted to a post."
        echo ""
    } > "$f"
}

_open_ideas() {
    _backlog_init
    grep -n '^- \[ \] ' "$(_backlog_path)" 2>/dev/null || true
}

_add_idea() {
    local text="$*"
    [[ -z "${text// /}" ]] && return 1
    _backlog_init
    printf -- '- [ ] %s  %s\n' "$(date +%F)" "$text" >> "$(_backlog_path)"
}

cmd_idea() {
    local text="$*"
    if [[ -z "${text// /}" ]]; then
        echo 'usage: blog.sh idea "your idea here"'
        return 1
    fi
    _add_idea "$text"
    echo ":: + $text"
}

cmd_backlog() {
    _backlog_init
    local open done_
    open="$(grep -c '^- \[ \] ' "$(_backlog_path)" || true)"
    done_="$(grep -c '^- \[x\] ' "$(_backlog_path)" || true)"

    echo ":: backlog — $open open, $done_ promoted"
    echo ""
    if [[ "$open" -eq 0 ]]; then
        echo "  (empty — capture some with: ./blog.sh idea \"...\")"
    else
        grep '^- \[ \] ' "$(_backlog_path)" | sed 's|^- \[ \] |  • |'
    fi
}

# interactive capture loop: type an idea, hit enter, it is saved. q to quit.
cmd_capture() {
    _backlog_init
    echo ":: capture mode — one idea per line"
    echo ":: 'l' list · 'q' quit"
    echo ""
    local line
    while IFS= read -r -e -p "idea> " line; do
        case "$line" in
            "") continue ;;
            q|quit|exit) break ;;
            l|list) echo ""; cmd_backlog; echo "" ; continue ;;
        esac
        _add_idea "$line" && echo "   saved."
    done
    echo ""
    echo ":: bye"
}

# promote a backlog idea into a real post file, then tick it off
cmd_promote() {
    cd "$SCRIPT_DIR"
    local target="${1:-}" category="${2:-General}"

    local ideas picked lineno text
    ideas="$(_open_ideas)"
    picked="$(_pick "$ideas" "promote idea" "$target")" || return $?

    lineno="${picked%%:*}"
    text="$(echo "${picked#*:}" | sed -E 's|^- \[ \] [0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]]+||')"

    cmd_new "$text" "$category" || return 1

    local slug filepath
    slug="$(echo "$text" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-')"
    filepath="${CFG[posts_dir]}/$(date +%F)-$slug.md"

    # tick the line off in place, recording where it went
    sed -i "${lineno}s|^- \[ \]|- [x]|; ${lineno}s|\$| -> $filepath|" "$(_backlog_path)"
    echo ":: promoted -> $filepath"
}

cmd_help() {
    cat <<EOF
usage: blog.sh <command> [args]

commands:
  build              build site to ${CFG[site_dir]}/
  serve [on|off]     local preview (drafts on/off, default: on)
  deploy [msg]       build + commit + push (default msg: "update blog")
  new "title" [cat]  create a new post (private by default; --public to opt out)
                     --tags "a,b,c" adds tags (public posts only; see below)
  publish [name]     remove "draft: true" from a post (interactive fzf if no name)
  zenitsu [name]     mark a post private → /zenitsu/ (interactive fzf if no name)
  private [name]     ONE-SHOT: private + undraft + build + commit + push
  revise [name]      edit an existing post -> confirm -> rebuild + push
  daily <kind>       5-min private journal; publishes on save
                     kinds: learned, done   (--no-push to hold it back)
  submit             deploy BOTH of today's daily posts private -> /zenitsu/

  idea "text"        append an idea to ${CFG[backlog]}
  capture            interactive idea-capture loop (q to quit)
  backlog            list open ideas
  promote [m] [cat]  turn a backlog idea into a post + tick it off
  help               show this message

categories: General, Papers, Learning, Hindi, Projects, Snippets, Problems

tag taxonomy (pick ONE type tag + topic tags; browse at /tags/):
  thoughts        thoughts, philosophy
  portfolio       portfolio, project-write-up
  tech knowledge  snippet, til, learning-notes, paper-notes
  problems        problem-solving, leetcode, advent-of-code
  topics          nlp, llm, pytorch, deep-learning, low-level, agentic-ai, ...

note: private (zenitsu) posts never get tags — the build strips them so the
tag index and search never leak a private URL.
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
        new)     cmd_new "$@" ;;
        publish) cmd_publish "$@" ;;
        zenitsu) cmd_zenitsu "$@" ;;
        private|deploy-private) cmd_private_deploy "$@" ;;
        revise)  cmd_revise "$@" ;;
        daily)   cmd_daily "$@" ;;
        submit|submit-daily) cmd_submit_daily "$@" ;;
        idea)    cmd_idea "$@" ;;
        capture) cmd_capture ;;
        backlog) cmd_backlog ;;
        promote) cmd_promote "$@" ;;
        help)    cmd_help ;;
        *)      echo "unknown command: $cmd"; cmd_help; exit 1 ;;
    esac
}

main "$@"
