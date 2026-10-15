#!/usr/bin/env bash
set -euo pipefail

FOLDER="dotfiles"

FILES=(
  ".ssh/config"
  ".ssh/id_rsa"
  ".ssh/id_rsa.pub"
  ".local/.wakatime.cfg"
  ".config/zsh/env.local.zsh"
)

HOST=""
HOST_FILES=()

to_item_name() {
  local p="$1"
  if [[ "$p" == /* ]]; then
    case "$p" in
      "$HOME"/*) echo "${p#"$HOME"/}" ;;
      *) echo "path not under HOME: $p" >&2; return 1 ;;
    esac
  else
    echo "$p"
  fi
}

is_host_file() {
  local path candidate
  path="$(to_item_name "$1")" || return 1
  for candidate in "${HOST_FILES[@]}"; do
    [[ "$(to_item_name "$candidate")" == "$path" ]] && return 0
  done
  return 1
}

to_vault_item_name() {
  local name
  name="$(to_item_name "$1")" || return 1
  if is_host_file "$1"; then
    printf 'hosts/%s/%s\n' "$HOST" "$name"
  else
    printf '%s\n' "$name"
  fi
}

validate_file_scopes() {
  local shared host shared_name host_name
  for shared in "${FILES[@]}"; do
    shared_name="$(to_item_name "$shared")" || return 1
    for host in "${HOST_FILES[@]}"; do
      host_name="$(to_item_name "$host")" || return 1
      if [[ "$shared_name" == "$host_name" ]]; then
        echo "file appears in both shared and host scopes: $shared_name" >&2
        return 1
      fi
    done
  done
}

# ---- args: -y / --yes ----
YES=0
cmd="list"
while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes) YES=1; shift ;;
    list|push|pull|files) cmd="$1"; shift ;;
    -h|--help)
      echo "Usage: $0 [-y|--yes] {list|push|pull|files}"
 exit 0
      ;;
    *)
      echo "Unknown arg: $1"
      echo "Usage: $0 [-y|--yes] {list|push|pull|files}"
      exit 1
      ;;
  esac
done

HOST="$(hostname -s)" || { echo "unable to determine short hostname" >&2; exit 1; }
if [[ -z "$HOST" || ! "$HOST" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]]; then
  echo "unsafe short hostname for host-scoped vault names" >&2
  exit 1
fi
HOST_FILES=(
  ".config/opencode-telegram-bot/env.${HOST}.zsh"
)
validate_file_scopes || exit 1

if [[ "$cmd" == "files" ]]; then
  printf '%s\n' "${FILES[@]}" "${HOST_FILES[@]}"
  exit 0
fi

export BW_SESSION="$(bw unlock --raw)"
bw sync >/dev/null 2>&1 || true

FOLDER_ID="$(bw list folders | jq -r --arg n "$FOLDER" '.[] | select(.name==$n) | .id' | head -n1)"
[ -n "$FOLDER_ID" ] && [ "$FOLDER_ID" != "null" ] || { echo "folder not found: $FOLDER"; exit 1; }

get_item_id() {
  local name="$1"
  bw list items --folderid "$FOLDER_ID" --search "$name" \
    | jq -r --arg n "$name" '.[] | select(.name==$n) | .id' \
    | head -n1
}

confirm() {
  local prompt="$1"
  if [[ "$YES" == "1" ]]; then
    return 0
  fi
  read -r -p "$prompt [y/N] " ans
  [[ "$ans" == "y" || "$ans" == "Y" ]]
}

show_diff_if_any() {
  local a="$1" b="$2" label_a="$3" label_b="$4"
  if diff -u --label "$label_a" --label "$label_b" "$a" "$b" >/dev/null 2>&1; then
    return 1
  else
    diff -u --label "$label_a" --label "$label_b" "$a" "$b" || true
    return 0
  fi
}

cleanup_tmp() {
  rm -f "${tmp_local:-}" "${tmp_remote:-}"
  tmp_local=""
  tmp_remote=""
}

tmp_local=""
tmp_remote=""

case "$cmd" in
  list)
    bw list items --folderid "$FOLDER_ID" \
      | jq -r 'sort_by(.name)[] | "\(.name)\t\(.revisionDate)"' \
      | column -t -s $'\t'
    ;;

  push)
    for f in "${FILES[@]}" "${HOST_FILES[@]}"; do
      local_name="$(to_item_name "$f")" || exit 1
      name="$(to_vault_item_name "$f")" || exit 1
      src="$HOME/$local_name"
      if is_host_file "$f" && [[ ! -f "$src" ]]; then
        echo "skip missing optional file: $local_name"
        continue
      fi
      [ -f "$src" ] || { echo "missing file: $src" >&2; exit 1; }

      item_id="$(get_item_id "$name" || true)"

      tmp_local="$(mktemp)"
      trap cleanup_tmp EXIT
      tmp_remote="$(mktemp)"

      cat -- "$src" > "$tmp_local"

      if [[ -z "${item_id:-}" || "$item_id" == "null" ]]; then
        : > "$tmp_remote"
        echo "diff (create) for: $name"
        if show_diff_if_any "$tmp_remote" "$tmp_local" "bw:$name (absent)" "local:$local_name"; then
          confirm "Create item in Bitwarden for $name?" || { echo "skip: $name"; cleanup_tmp; continue; }
        else
          echo "no changes: $name"
          cleanup_tmp
          continue
        fi

        content="$(cat -- "$tmp_local")"
        item_json="$(jq -n \
  --arg folderId "$FOLDER_ID" \
    --arg name "$name" \
    --arg notes "$content" \
    '{type:2,name:$name,folderId:$folderId,notes:$notes,secureNote:{type:0}}')"

        echo "create: $name"
        echo "$item_json" | bw encode | bw create item >/dev/null
      else
        bw get item "$item_id" | jq -r '.notes // ""' > "$tmp_remote"

        echo "diff (push) for: $name"
        if show_diff_if_any "$tmp_remote" "$tmp_local" "bw:$name" "local:$local_name"; then
          confirm "Push local changes to Bitwarden for $name?" || { echo "skip: $name"; cleanup_tmp; continue; }
        else
          echo "no changes: $name"
          cleanup_tmp
          continue
        fi

        content="$(cat -- "$tmp_local")"
        item_json="$(
          bw get template item \
          | jq -n --arg folderId "$FOLDER_ID" --arg name "$name" --arg notes "$content" '
                .type=2
              | .name=$name
              | .folderId=$folderId
              | .notes=$notes
              | .secureNote.type=0'
          )"
        echo "update: $name"
        echo "$item_json" | bw encode | bw edit item "$item_id" >/dev/null
      fi

      cleanup_tmp
      trap - EXIT
      chmod 0400 ~/.ssh/id_rsa
    done
    ;;

  pull)
    for f in "${FILES[@]}" "${HOST_FILES[@]}"; do
      local_name="$(to_item_name "$f")" || exit 1
      name="$(to_vault_item_name "$f")" || exit 1
      item_id="$(get_item_id "$name" || true)"
      if is_host_file "$f" && [[ -z "$item_id" || "$item_id" == "null" ]]; then
        echo "skip optional item not found: $name"
        continue
      fi
      [[ -n "${item_id:-}" && "$item_id" != "null" ]] || { echo "item not found: $name" >&2; exit 1; }

      tmp_local="$(mktemp)"
      trap cleanup_tmp EXIT
      tmp_remote="$(mktemp)"

      bw get item "$item_id" | jq -r '.notes // ""' > "$tmp_remote"

      dst="$HOME/$local_name"
      mkdir -p "$(dirname -- "$dst")"

      if [[ -f "$dst" ]]; then
        cat -- "$dst" > "$tmp_local"
      else
        : > "$tmp_local"
      fi

      echo "diff (pull) for: $name"
      if show_diff_if_any "$tmp_local" "$tmp_remote" "local:$local_name" "bw:$name"; then
        confirm "Overwrite local file from Bitwarden for $name?" || { echo "skip: $name"; cleanup_tmp; continue; }
      else
        echo "no changes: $name"
        cleanup_tmp
        continue
      fi

      cat -- "$tmp_remote" > "$dst"
      if is_host_file "$f"; then
        chmod 600 "$dst"
        echo "pulled: $local_name (Bitwarden: $name)"
      else
        echo "pulled: $local_name"
      fi

      cleanup_tmp
      trap - EXIT
    done
    ;;

  *)
    echo "Usage: $0 [-y|--yes] {list|push|pull|files}"
    exit 1
    ;;
esac
