#!/usr/bin/env bash
# Gives a host that only has one repository (CI, Vercel) the shared engines its
# pubspec reads by path, such as ../../shipglows-app-engine/flutter/core/....
#
#   curl -fsSL https://raw.githubusercontent.com/commandglows/app-engine/main/tool/provide-engines.sh | bash -s -- [dir]
#
# dir holds the pubspec.yaml to follow (default: current directory). The search
# follows path dependencies through the engines it clones. An existing folder is
# kept as it is, so a developer checkout is never changed.
#
# Each engine comes from its main branch. To pin one, add a line
# "<repository> <commit>" to an `engine-refs` file next to the pubspec.yaml.
set -euo pipefail

CLONE_BASE="${ENGINE_CLONE_BASE:-https://github.com/commandglows}"
START="$(cd "${1:-.}" && pwd -P)"
REFS_FILE="$START/engine-refs"

repository_of() {
  case "$1" in
    shipglows-app-engine) echo app-engine ;;
    shipglows-audio-engine) echo audio-engine ;;
    shipglows-email-engine) echo email-engine ;;
    shipglows-analytics-engine) echo analytics-engine ;;
    *) echo "" ;;
  esac
}

provide() {
  local destination="$1" repository="$2" ref=""
  [[ -e "$destination" ]] && return 0
  if [[ -f "$REFS_FILE" ]]; then
    ref="$(awk -v repo="$repository" '$1 == repo { print $2 }' "$REFS_FILE")"
  fi
  if [[ -n "$ref" ]]; then
    echo "Cloning $repository at $ref" >&2
    git clone --quiet --no-checkout "$CLONE_BASE/$repository" "$destination"
    git -C "$destination" checkout --quiet --detach "$ref"
  else
    echo "Cloning $repository" >&2
    git clone --quiet --depth 1 --single-branch --branch main "$CLONE_BASE/$repository" "$destination"
  fi
}

# Absolute path of $2 seen from directory $1, cloning its engine when missing.
resolve() {
  local base="$1" relative="$2" prefix="" rest="$2" part engine=""
  while [[ "$rest" == */* ]]; do
    part="${rest%%/*}"
    if [[ -n "$(repository_of "$part")" ]]; then
      engine="$part"
      break
    fi
    prefix="$prefix$part/"
    rest="${rest#*/}"
  done
  if [[ -n "$engine" ]]; then
    mkdir -p "$base/$prefix"
    provide "$(cd "$base/$prefix" && pwd -P)/$engine" "$(repository_of "$engine")"
  fi
  (cd "$base/${relative%/*}" 2>/dev/null && echo "$(pwd -P)/${relative##*/}")
}

queue="$START"
seen=""
while [[ -n "$queue" ]]; do
  directory="${queue%%$'\n'*}"
  if [[ "$queue" == *$'\n'* ]]; then queue="${queue#*$'\n'}"; else queue=""; fi
  case "$seen" in *"|$directory|"*) continue ;; esac
  seen="$seen|$directory|"
  while IFS= read -r relative; do
    [[ -z "$relative" ]] && continue
    target="$(resolve "$directory" "$relative")" || target=""
    if [[ -z "$target" || ! -f "$target/pubspec.yaml" ]]; then
      echo "ERROR: $directory/pubspec.yaml depends on $relative, which has no pubspec.yaml" >&2
      exit 1
    fi
    queue="${queue:+$queue$'\n'}$target"
  done < <(sed -nE "s/^[[:space:]]+path:[[:space:]]*[\"']?([^\"' #]+)[\"']?.*$/\1/p" "$directory/pubspec.yaml" | tr -d '\r' | grep -E '^\.\.?(/|$)' || true)
done
echo "Engines ready."
