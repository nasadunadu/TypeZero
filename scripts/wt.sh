#!/usr/bin/env bash
# TypeZero Multi-Agent Parallel Worktree Orchestrator
# Usage:
#   ./scripts/wt.sh create <slug> [--owner <conv_id>] [--title "<desc>"] [--from <ref>]
#   ./scripts/wt.sh list
#   ./scripts/wt.sh status
#   ./scripts/wt.sh sync <slug>
#   ./scripts/wt.sh check <slug>
#   ./scripts/wt.sh merge <slug> [--keep]
#   ./scripts/wt.sh close <slug> [--force]

set -euo pipefail

resolve_trunk_dir() {
    local first_wt
    first_wt="$(git worktree list --porcelain 2>/dev/null | awk '/^worktree / {print substr($0, 10); exit}')"
    if [ -n "$first_wt" ]; then
        echo "$first_wt"
    else
        cd "$(dirname "$0")/.." && pwd
    fi
}

TRUNK_DIR="$(resolve_trunk_dir)"
WT_ROOT="$TRUNK_DIR/.worktrees"
GIT_COMMON_DIR="$(git -C "$TRUNK_DIR" rev-parse --git-common-dir)"
if [[ "$GIT_COMMON_DIR" != /* ]]; then
    GIT_COMMON_DIR="$TRUNK_DIR/$GIT_COMMON_DIR"
fi

ensure_common_excludes() {
    local exclude_file="$GIT_COMMON_DIR/info/exclude"
    mkdir -p "$(dirname "$exclude_file")"
    touch "$exclude_file"
    for pat in ".worktrees/" ".agents/" ".agents" "AGENTS.md" "Vendor" "site/media" "cloud/node_modules" ".lane-owner.json"; do
        if ! grep -qxF "$pat" "$exclude_file" 2>/dev/null; then
            echo "$pat" >> "$exclude_file"
        fi
    done
}

move_to_trash() {
    local target="$1"
    [ -e "$target" ] || [ -L "$target" ] || return 0
    if command -v /usr/bin/trash >/dev/null 2>&1; then
        /usr/bin/trash "$target" 2>/dev/null && return 0
    fi
    local fallback_dir="$HOME/.Trash/typezero-wt-$(date +%s)-$$"
    mkdir -p "$fallback_dir"
    mv "$target" "$fallback_dir/"
}

normalize_slug() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's#^feat/##; s#[^a-z0-9._-]+#-#g; s#(^-|-$)##g'
}

link_shared_assets() {
    local wt_dir="$1"
    # Share heavy C++ runtime dylibs (Vendor/) with zero disk duplication
    if [ -d "$TRUNK_DIR/Vendor" ] && [ ! -e "$wt_dir/Vendor" ]; then
        ln -s "$TRUNK_DIR/Vendor" "$wt_dir/Vendor"
    fi
    # Share local workspace governance & skills/hooks
    if [ -f "$TRUNK_DIR/AGENTS.md" ] && [ ! -e "$wt_dir/AGENTS.md" ]; then
        ln -s "$TRUNK_DIR/AGENTS.md" "$wt_dir/AGENTS.md"
    fi
    if [ -d "$TRUNK_DIR/.agents" ] && [ ! -e "$wt_dir/.agents" ]; then
        ln -s "$TRUNK_DIR/.agents" "$wt_dir/.agents"
    fi
    if [ -d "$TRUNK_DIR/site/media" ] && [ -d "$wt_dir/site" ] && [ ! -e "$wt_dir/site/media" ]; then
        ln -s "$TRUNK_DIR/site/media" "$wt_dir/site/media"
    fi
    if [ -d "$TRUNK_DIR/cloud/node_modules" ] && [ -d "$wt_dir/cloud" ] && [ ! -e "$wt_dir/cloud/node_modules" ]; then
        ln -s "$TRUNK_DIR/cloud/node_modules" "$wt_dir/cloud/node_modules"
    fi
}

unlink_shared_symlinks() {
    local wt_dir="$1"
    for rel in "Vendor" "AGENTS.md" ".agents" "site/media" "cloud/node_modules" ".lane-owner.json"; do
        if [ -L "$wt_dir/$rel" ] || [ "$rel" = ".lane-owner.json" ]; then
            move_to_trash "$wt_dir/$rel"
        fi
    done
}

cmd_create() {
    if [ $# -lt 1 ]; then
        echo "Usage: $0 create <slug> [--owner <conv_id>] [--title \"<desc>\"] [--from <ref>]" >&2
        exit 1
    fi
    local raw_slug="$1"
    shift
    local slug
    slug="$(normalize_slug "$raw_slug")"
    local owner=""
    local explicit_owner=false
    local title=""
    local base_ref="main"

    while [ $# -gt 0 ]; do
        case "$1" in
            --owner) owner="${2:-}"; explicit_owner=true; shift 2 ;;
            --title) title="${2:-}"; shift 2 ;;
            --from)  base_ref="${2:-main}"; shift 2 ;;
            *) echo "Unknown flag: $1" >&2; exit 1 ;;
        esac
    done

    ensure_common_excludes
    mkdir -p "$WT_ROOT"
    local wt_dir="$WT_ROOT/$slug"
    local branch="feat/$slug"

    if [ -d "$wt_dir/.git" ] || [ -f "$wt_dir/.git" ]; then
        echo "==> Worktree lane '$slug' already exists at: $wt_dir"
    else
        if git -C "$TRUNK_DIR" show-ref --verify --quiet "refs/heads/$branch"; then
            git -C "$TRUNK_DIR" worktree add "$wt_dir" "$branch"
        else
            git -C "$TRUNK_DIR" worktree add -b "$branch" "$wt_dir" "$base_ref"
        fi
    fi

    link_shared_assets "$wt_dir"

    local owner_file="$wt_dir/.lane-owner.json"
    local default_env_owner="${ANTIGRAVITY_CONVERSATION_ID:-}"
    python3 - "$owner_file" "$slug" "$branch" "$owner" "$explicit_owner" "$default_env_owner" "$title" <<'PY'
import json, os, sys
path, slug, branch, owner, explicit_owner, default_env_owner, title = sys.argv[1:8]
existing = {}
if os.path.exists(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            existing = json.load(f)
    except Exception:
        existing = {}
prev_owner = existing.get("ownerConversationId", "")
if explicit_owner == "true":
    resolved_owner = owner
else:
    resolved_owner = prev_owner or default_env_owner
data = {
    "slug": slug,
    "branch": branch,
    "ownerConversationId": resolved_owner,
    "title": title or existing.get("title", ""),
}
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
PY

    echo "==> Ready! Isolated Parallel Lane:"
    echo "    Slug   : $slug"
    echo "    Branch : $branch"
    echo "    Path   : $wt_dir"
    echo "    Owner  : ${owner:-<unassigned>}"
    echo "    AppOut : $wt_dir/build.noindex/TypeZero.app"
}

cmd_status() {
    ensure_common_excludes
    printf "%-16s %-22s %-12s %-10s %-14s %s\n" "LANE" "BRANCH" "AHEAD/BEHIND" "DIRTY" "OWNER" "PATH"
    printf "%-16s %-22s %-12s %-10s %-14s %s\n" "----" "------" "------------" "-----" "-----" "----"

    local trunk_branch trunk_dirty
    trunk_branch="$(git -C "$TRUNK_DIR" branch --show-current 2>/dev/null || echo detached)"
    trunk_dirty="$(git -C "$TRUNK_DIR" status --porcelain 2>/dev/null | grep -vc '^?? site' || true)"
    printf "%-16s %-22s %-12s %-10s %-14s %s\n" "[trunk]" "$trunk_branch" "0/0" "${trunk_dirty} files" "integration" "$TRUNK_DIR"

    if [ -d "$WT_ROOT" ]; then
        for wt_dir in "$WT_ROOT"/*; do
            [ -d "$wt_dir" ] || continue
            [ -e "$wt_dir/.git" ] || continue
            local slug branch counts ahead behind dirty owner
            slug="$(basename "$wt_dir")"
            branch="$(git -C "$wt_dir" branch --show-current 2>/dev/null || echo detached)"
            counts="$(git -C "$wt_dir" rev-list --left-right --count "main...HEAD" 2>/dev/null || echo "0	0")"
            behind="$(echo "$counts" | awk '{print $1}')"
            ahead="$(echo "$counts" | awk '{print $2}')"
            dirty="$(git -C "$wt_dir" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
            owner="-"
            if [ -f "$wt_dir/.lane-owner.json" ]; then
                owner="$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); o=d.get("ownerConversationId",""); print(o[:8] if o else "-")' "$wt_dir/.lane-owner.json" 2>/dev/null || echo "-")"
            fi
            printf "%-16s %-22s %-12s %-10s %-14s %s\n" "$slug" "$branch" "+${ahead}/-${behind}" "${dirty} files" "$owner" "$wt_dir"
        done
    fi
}

cmd_sync() {
    local slug
    slug="$(normalize_slug "${1:?Usage: $0 sync <slug>}")"
    local wt_dir="$WT_ROOT/$slug"
    [ -e "$wt_dir/.git" ] || { echo "Lane '$slug' not found at $wt_dir" >&2; exit 1; }
    echo "==> Rebasing lane '$slug' onto latest local 'main'..."
    git -C "$wt_dir" rebase main
    echo "==> Sync complete for '$slug'."
}

cmd_check() {
    local slug
    slug="$(normalize_slug "${1:?Usage: $0 check <slug>}")"
    local wt_dir="$WT_ROOT/$slug"
    [ -e "$wt_dir/.git" ] || { echo "Lane '$slug' not found at $wt_dir" >&2; exit 1; }
    local branch
    branch="$(git -C "$wt_dir" branch --show-current)"

    echo "==> [1/3] Checking uncommitted working tree in '$slug'..."
    if [ -n "$(git -C "$wt_dir" status --porcelain)" ]; then
        echo "  ! Warning: '$slug' still has uncommitted files (commit before final merge):"
        git -C "$wt_dir" status --short
    else
        echo "  ✓ Working tree is clean."
    fi

    echo "==> [2/3] Running zero-touch merge conflict dry-run against 'main'..."
    if git -C "$TRUNK_DIR" merge-tree --write-tree main "$branch" >/dev/null 2>&1; then
        echo "  ✓ Zero merge conflicts with 'main'."
    else
        echo "  ✗ Merge conflict detected between 'main' and '$branch'!" >&2
        git -C "$TRUNK_DIR" merge-tree --write-tree main "$branch" || true
        exit 1
    fi

    echo "==> [3/3] Running isolated build & test suite inside '$wt_dir'..."
    (cd "$wt_dir" && ./scripts/run-tests.sh)
    if git -C "$TRUNK_DIR" diff --name-only "main...$branch" | grep -q '^cloud/'; then
        echo "==> Cloud backend changes detected; running cloud test suite..."
        (cd "$wt_dir/cloud" && npm test)
    fi
    echo "==> ✓ All pre-merge gates passed for '$slug' ($branch)!"
}

cmd_merge() {
    local slug=""
    local keep=false
    while [ $# -gt 0 ]; do
        case "$1" in
            --keep) keep=true; shift ;;
            *) slug="$(normalize_slug "$1")"; shift ;;
        esac
    done
    [ -n "$slug" ] || { echo "Usage: $0 merge <slug> [--keep]" >&2; exit 1; }
    local wt_dir="$WT_ROOT/$slug"
    [ -e "$wt_dir/.git" ] || { echo "Lane '$slug' not found at $wt_dir" >&2; exit 1; }
    local branch
    branch="$(git -C "$wt_dir" branch --show-current)"

    if [ -n "$(git -C "$wt_dir" status --porcelain)" ]; then
        echo "Error: Lane '$slug' has uncommitted changes. Commit them inside $wt_dir first." >&2
        git -C "$wt_dir" status --short >&2
        exit 1
    fi

    cmd_check "$slug"

    mkdir -p "$WT_ROOT"
    local lock_file="$WT_ROOT/.merge-lock"
    echo "$slug" > "$lock_file"
    trap 'move_to_trash "'"$lock_file"'"' EXIT

    echo "==> Merging '$branch' into protected 'main' trunk..."
    git -C "$TRUNK_DIR" checkout main
    git -C "$TRUNK_DIR" merge --no-ff "$branch" -m "merge($slug): integrate $branch into main"

    echo "==> Running post-merge trunk verification..."
    (cd "$TRUNK_DIR" && ./scripts/run-tests.sh)

    move_to_trash "$lock_file"
    trap - EXIT

    if [ "$keep" = false ]; then
        cmd_close "$slug"
    fi
    echo "==> ✓ Successfully merged '$branch' into 'main'!"
}

cmd_close() {
    local slug=""
    local force=false
    while [ $# -gt 0 ]; do
        case "$1" in
            --force) force=true; shift ;;
            *) slug="$(normalize_slug "$1")"; shift ;;
        esac
    done
    [ -n "$slug" ] || { echo "Usage: $0 close <slug> [--force]" >&2; exit 1; }
    local wt_dir="$WT_ROOT/$slug"
    [ -e "$wt_dir/.git" ] || { echo "Lane '$slug' not found at $wt_dir" >&2; exit 1; }
    local branch
    branch="$(git -C "$wt_dir" branch --show-current)"

    if [ "$force" = false ]; then
        if [ -n "$(git -C "$wt_dir" status --porcelain)" ]; then
            echo "Error: Lane '$slug' has uncommitted changes. Commit first or pass --force." >&2
            exit 1
        fi
        if ! git -C "$TRUNK_DIR" merge-base --is-ancestor "$branch" main 2>/dev/null; then
            echo "Error: Branch '$branch' has unmerged commits not yet in 'main'. Merge first or pass --force." >&2
            exit 1
        fi
    fi

    echo "==> Closing worktree lane '$slug'..."
    unlink_shared_symlinks "$wt_dir"
    move_to_trash "$wt_dir/.build"
    move_to_trash "$wt_dir/build.noindex"
    git -C "$TRUNK_DIR" worktree remove "$wt_dir" --force
    if [ "$force" = true ]; then
        git -C "$TRUNK_DIR" branch -D "$branch" 2>/dev/null || true
    else
        git -C "$TRUNK_DIR" branch -d "$branch" 2>/dev/null || true
    fi
    echo "==> ✓ Closed lane '$slug' cleanly."
}

ACTION="${1:-status}"
shift || true
case "$ACTION" in
    create) cmd_create "$@" ;;
    list|status) cmd_status "$@" ;;
    sync)   cmd_sync "$@" ;;
    check)  cmd_check "$@" ;;
    merge)  cmd_merge "$@" ;;
    close)  cmd_close "$@" ;;
    *)
        echo "Usage: $0 {create|list|status|sync|check|merge|close} ..." >&2
        exit 1
        ;;
esac
