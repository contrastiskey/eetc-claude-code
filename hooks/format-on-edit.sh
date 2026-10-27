#!/bin/bash
# PostToolUse hook for Edit|Write: formats the edited file with the formatter the
# project is already configured for. No matching config or no formatter
# installed → no-op, so it never reformats a repo that doesn't use it.
f=$(jq -r '.tool_input.file_path // ""')
[[ -f "$f" ]] || exit 0

# first dir at or above the edited file holding one of FILES that matches PATTERN
config_dir() {
  local pat=$1 d n
  shift
  d=$(dirname "$f")
  while :; do
    for n in "$@"; do
      [[ -f "$d/$n" ]] && grep -qiE "$pat" "$d/$n" && { echo "$d"; return 0; }
    done
    [[ "$d" == / || "$d" == . ]] && return 1
    d=$(dirname "$d")
  done
}

# project venv first, then PATH
find_tool() {
  local t
  for t in "$root/.venv/bin/$1" "${CLAUDE_PROJECT_DIR:-.}/.venv/bin/$1" "$(command -v "$1")"; do
    [[ -n "$t" && -x "$t" ]] && { echo "$t"; return 0; }
  done
  return 1
}

case "$f" in
  *.py | *.pyi)
    # --force-exclude keeps configured excludes (migrations, generated code) untouched
    root=$(config_dir . ruff.toml .ruff.toml) || root=$(config_dir '^\[tool\.ruff' pyproject.toml) || exit 0
    bin=$(find_tool ruff) && "$bin" format -q --force-exclude "$f"
    ;;
  *.rs)
    root=$(config_dir . Cargo.toml) && bin=$(command -v rustfmt) || exit 0
    # standalone rustfmt defaults to edition 2015; a workspace member inherits
    # it from a Cargo.toml further up
    d=$root
    while [[ -z "$ed" && "$d" != / ]]; do
      [[ -f "$d/Cargo.toml" ]] && ed=$(sed -nE 's/^edition *= *"([0-9]+)".*/\1/p' "$d/Cargo.toml" | head -1)
      d=$(dirname "$d")
    done
    # ponytail: rustfmt also formats out-of-line child modules (`mod foo;`), a no-op on rustfmt-clean crates
    "$bin" -q --edition "${ed:-2021}" "$f"
    ;;
  *.java)
    # Spotless per edit starts Maven (too slow), so call google-java-format directly
    root=$(config_dir 'google-?java-?format|googleJavaFormat' pom.xml build.gradle build.gradle.kts) \
      && bin=$(command -v google-java-format) || exit 0
    args=(--replace)
    cat "$root"/{pom.xml,build.gradle,build.gradle.kts} 2>/dev/null | grep -qi aosp && args+=(--aosp)
    "$bin" "${args[@]}" "$f"
    ;;
  */testdata/*.go | */vendor/*.go) ;; # the go tool skips these; fixtures may be unformatted on purpose
  *.go)
    config_dir . go.mod && bin=$(command -v gofmt) || exit 0
    "$bin" -w "$f"
    ;;
esac >/dev/null 2>&1
exit 0
