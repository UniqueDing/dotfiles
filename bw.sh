#!/usr/bin/env bash
set -e

FOLDER="dotfiles"

FILES=(
  ".ssh/config"
  ".ssh/id_rsa"
  ".ssh/id_rsa.pub"
  ".local/.wakatime.cfg"
)

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

export BW_SESSION="$(bw unlock --raw)"
bw sync >/dev/null 2>&1 || true

FOLDER_ID="$(bw list folders | jq -r --arg n "$FOLDER" '.[] | select(.name==$n) | .id' | head -n1)"
[ -n "$FOLDER_ID" ] && [ "$FOLDER_ID" != "null" ] || { echo "folder not found: $FOLDER"; exit 1; }

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

case "$cmd" in
  list)
    bw list items --folderid "$FOLDER_ID" \
      | jq -r 'sort_by(.name)[] | "\(.name)\t\(.revisionDate)"' \
      | column -t -s $'\t'
    ;;

  files)
    printf '%s\n' "${FILES[@]}"
    ;;

  push)
    for f in "${FILES[@]}"; do
      name="$(to_item_name "$f")" || exit 1
      src="$HOME/$name"
      [ -f "$src" ] || { echo "missing file: $src" >&2; exit 1; }

      item_id="$(get_item_id "$name" || true)"

      tmp_local="$(mktemp)"
      tmp_remote="$(mktemp)"
      trap 'rm -f "$tmp_local" "$tmp_remote"' EXIT

      cat -- "$src" > "$tmp_local"

      if [[ -z "${item_id:-}" || "$item_id" == "null" ]]; then
        : > "$tmp_remote"
        echo "diff (create) for: $name"
        if show_diff_if_any "$tmp_remote" "$tmp_local" "bw:$name (absent)" "local:$name"; then
          confirm "Create item in Bitwarden for $name?" || { echo "skip: $name"; continue; }
        else
          echo "no changes: $name"
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
        if show_diff_if_any "$tmp_remote" "$tmp_local" "bw:$name" "local:$name"; then
          confirm "Push local changes to Bitwarden for $name?" || { echo "skip: $name"; continue; }
        else
          echo "no changes: $name"
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
              | .secureNote.type={ "type=0" }'
          )"
        echo "update: $name"
        echo "$item_json" | bw encode | bw edit item "$item_id" >/dev/null
      fi

      rm -f "$tmp_local" "$tmp_remote"
      trap - EXIT
    done
    ;;

  pull)
    for f in "${FILES[@]}"; do
      name="$(to_item_name "$f")" || exit 1
      item_id="$(get_item_id "$name" || true)"
      [[ -n "${item_id:-}" && "$item_id" != "null" ]] || { echo "item not found: $name" >&2; exit 1; }

      tmp_local="$(mktemp)"
      tmp_remote="$(mktemp)"
      trap 'rm -f "$tmp_local" "$tmp_remote"' EXIT

      bw get item "$item_id" | jq -r '.notes // ""' > "$tmp_remote"

      dst="$HOME/$name"
      mkdir -p "$(dirname -- "$dst")"

      if [[ -f "$dst" ]]; then
        cat -- "$dst" > "$tmp_local"
      else
        : > "$tmp_local"
      fi

      echo "diff (pull) for: $name"
      if show_diff_if_any "$tmp_local" "$tmp_remote" "local:$name" "bw:$name"; then
        confirm "Overwrite local file from Bitwarden for $name?" || { echo "skip: $name"; continue; }
      else
        echo "no changes: $name"
        continue
      fi

      cat -- "$tmp_remote" > "$dst"
      echo "pulled: $name"

      rm -f "$tmp_local" "$tmp_remote"
      trap - EXIT
    done
    ;;

  *)
    echo "Usage: $0 [-y|--yes] {list|push|pull|files}"
    exit 1
    ;;
esac
