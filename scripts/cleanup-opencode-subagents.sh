#!/usr/bin/env bash
# Remove old OpenCode sessions.  Dry-run by default.
set -euo pipefail

DAYS=7
MODE="old-subagents"
INCLUDE_PRIMARY=false
QUIET_MINUTES=30
DELETE=false
BACKUP_DIR=""
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/opencode"

usage() {
  cat <<'EOF'
Usage: cleanup-opencode-subagents.sh [options]
       cleanup-opencode-subagents.sh help

List old OpenCode subagent sessions by default.

Options:
  --days N          Select subagents last updated more than N days ago (default: 7)
  --completed       Select subagents quiet for N minutes (default: 30)
  --quiet-minutes N Set the quiet window for --completed (default: 30)
  --older-than N    Select sessions last updated more than N days ago
  --include-primary Allow --older-than to include primary sessions
  --data-dir DIR    OpenCode data directory (default: ~/.local/share/opencode)
  --backup-dir DIR  Export each session to DIR before deleting it
  --delete          Delete the listed sessions after an explicit confirmation
  -h, --help        Show this help

Examples:
  # Preview old subagents (safe; makes no changes)
  scripts/cleanup-opencode-subagents.sh

  # Preview subagents that have been quiet for 30 minutes
  scripts/cleanup-opencode-subagents.sh --completed

  # Preview every session, including primary sessions, older than 15 days
  scripts/cleanup-opencode-subagents.sh --older-than 15 --include-primary

  # Export then delete the candidates (requires typing confirmation)
  scripts/cleanup-opencode-subagents.sh --days 7 --backup-dir ~/opencode-backups --delete

--older-than requires --include-primary. It excludes an old session when it
has a newer descendant, so deleting a stale parent cannot cascade into newer
work. This script does not run VACUUM and does not remove filesystem snapshots.
Run VACUUM only after every OpenCode process has stopped.
EOF
}

die() {
  echo "error: $*" >&2
  exit 1
}

while (($#)); do
  case "$1" in
    --days) MODE="old-subagents"; DAYS=${2:?--days needs a value}; shift 2 ;;
    --completed) MODE="completed"; shift ;;
    --quiet-minutes) QUIET_MINUTES=${2:?--quiet-minutes needs a value}; shift 2 ;;
    --older-than) MODE="old-sessions"; DAYS=${2:?--older-than needs a value}; shift 2 ;;
    --include-primary) INCLUDE_PRIMARY=true; shift ;;
    --data-dir) DATA_DIR=${2:?--data-dir needs a value}; shift 2 ;;
    --backup-dir) BACKUP_DIR=${2:?--backup-dir needs a value}; shift 2 ;;
    --delete) DELETE=true; shift ;;
    help|-h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

[[ $DAYS =~ ^[0-9]+$ ]] || die "--days must be a non-negative integer"
[[ $QUIET_MINUTES =~ ^[0-9]+$ ]] || die "--quiet-minutes must be a non-negative integer"
[[ $MODE != "old-sessions" || $INCLUDE_PRIMARY == true ]] || die "--older-than requires --include-primary"
DB="$DATA_DIR/opencode-stable.db"
[[ -r $DB ]] || die "database not readable: $DB"
command -v sqlite3 >/dev/null || die "sqlite3 is required"
OPENCODE=$(command -v opencode || true)
if [[ -z $OPENCODE && -x $HOME/.nix-profile/bin/opencode ]]; then
  OPENCODE=$HOME/.nix-profile/bin/opencode
fi
[[ -n $OPENCODE ]] || die "opencode is required in PATH or ~/.nix-profile/bin"

case "$MODE" in
  old-subagents)
    LABEL="subagent session(s) older than $DAYS day(s)"
    WHERE="root.parent_id IS NOT NULL AND root.time_updated < (strftime('%s', 'now') * 1000 - $DAYS * 86400000)"
    ;;
  completed)
    LABEL="subagent session(s) quiet for $QUIET_MINUTES minute(s)"
    WHERE="root.parent_id IS NOT NULL AND root.time_updated < (strftime('%s', 'now') * 1000 - $QUIET_MINUTES * 60000)"
    ;;
  old-sessions)
    LABEL="session(s), including primary sessions, older than $DAYS day(s)"
    # Keep old ancestors of newer work: session deletion cascades to descendants.
    WHERE="root.time_updated < (strftime('%s', 'now') * 1000 - $DAYS * 86400000) AND NOT EXISTS (WITH RECURSIVE descendants(id) AS (SELECT id FROM session WHERE parent_id = root.id UNION ALL SELECT s.id FROM session s JOIN descendants d ON s.parent_id = d.id) SELECT 1 FROM session s2 JOIN descendants d ON d.id = s2.id WHERE s2.time_updated >= (strftime('%s', 'now') * 1000 - $DAYS * 86400000))"
    ;;
esac

mapfile -t SESSIONS < <(sqlite3 -readonly "$DB" "
  PRAGMA busy_timeout=2000;
  SELECT id || char(9) || COALESCE(agent, '-') || char(9) ||
         datetime(time_updated / 1000, 'unixepoch', 'localtime') || char(9) ||
         replace(replace(COALESCE(title, '(untitled)'), char(9), ' '), char(10), ' ')
  FROM session AS root
  WHERE id <> '' AND $WHERE
  ORDER BY time_updated;
" | tail -n +2)

if ((${#SESSIONS[@]} == 0)); then
  echo "No $LABEL."
  exit 0
fi

printf 'Candidates: %d %s\n\n' "${#SESSIONS[@]}" "$LABEL"
printf 'ID\tAGENT\tLAST UPDATED\tTITLE\n'
printf '%s\n' "${SESSIONS[@]}"

if [[ $DELETE != true ]]; then
  echo
  echo "Dry run only. Re-run with --delete to remove these sessions."
  exit 0
fi

if [[ -n $BACKUP_DIR ]]; then
  mkdir -p "$BACKUP_DIR"
fi

read -r -p "Type DELETE ${#SESSIONS[@]} SESSIONS to continue: " CONFIRM
[[ $CONFIRM == "DELETE ${#SESSIONS[@]} SESSIONS" ]] || die "confirmation did not match; nothing deleted"

deleted=0
skipped=0
for row in "${SESSIONS[@]}"; do
  id=${row%%$'\t'*}
  if [[ -n $BACKUP_DIR ]]; then
    if ! "$OPENCODE" export "$id" >"$BACKUP_DIR/$id.json"; then
      echo "skip $id: export failed" >&2
      ((skipped+=1))
      continue
    fi
  fi
  if "$OPENCODE" session delete "$id"; then
    ((deleted+=1))
  else
    echo "skip $id: delete failed" >&2
    ((skipped+=1))
  fi
done

printf 'Done: deleted=%d skipped=%d\n' "$deleted" "$skipped"
