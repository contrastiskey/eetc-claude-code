#!/bin/bash
# PostToolUse hook for Bash: shrinks what Claude sees from *successful* noisy
# commands: dependency installs, cargo / mvn / docker builds, and lockfile hunks
# in git diffs. The command already ran unchanged under the normal permission
# flow. Failed commands fire PostToolUseFailure instead, so errors arrive in full.
in=$(cat)
[[ $(jq '.tool_response.isImage or .tool_response.interrupted' <<<"$in") == true ]] && exit 0
cmd=$(jq -r '.tool_input.command // ""' <<<"$in")
out=$(jq -r '.tool_response.stdout // ""' <<<"$in")
err=$(jq -r '.tool_response.stderr // ""' <<<"$in")

# one command, optionally after `cd <dir> &&` / venv activation, nothing chained after
pre='^(cd [^;&|]+ && )?(source \.venv/bin/activate && )?'
end='( |$)[^;&|]*( 2>&1)?$'
install_re="${pre}((([^ ;&|]*/)?python3? -m |[^ ;&|]*/)?pip3? install|uv (sync|add|remove|lock|pip install)|poetry (install|add|remove|update|lock)|(npm|pnpm) (install|i|ci|add)|yarn (install|add))${end}"
docker_re="${pre}docker (build|buildx build|compose( [^;&|]*)? build)${end}"
cargo_re="${pre}cargo (\+[^ ]+ )?(build|check|clippy|doc)${end}"
mvn_re="${pre}(mvn|\./mvnw)${end}"
mvn_lifecycle='(^| )(compile|test-compile|test|verify|package|install)( |$)'
mvn_plugin_goal='(^| )[a-z-]+:[a-z-]+( |$)' # dependency:tree etc. log their result at [INFO]
git_re='(^|[;&|(] *)git '
names_lockfile='\.lock|-lock\.|go\.sum'

# first and last 3 lines, plus up to 30 warning / error / summary lines between them
# (uv, pip, npm and poetry summaries: "Installed 27 packages", "added 65 packages", ...)
ends() {
  awk '{ l[NR] = $0 }
    END {
      for (i = 1; i <= NR; i++) {
        keep[i] = NR <= 30 || i <= 3 || i > NR - 3 \
          || (tolower(l[i]) ~ /warn|error|conflict|vulnerab|^ *(resolved|prepared|installed|uninstalled|audited|successfully|added|removed|changed|updated|up to date|package operations|writing lock)/ && k++ < 30)
        cut += !keep[i]
      }
      for (i = 1; i <= NR; i++)
        if (keep[i]) print l[i]
        else if (!shown++) print "[... " cut " lines of successful output trimmed by the eetc hook ...]"
    }'
}

# warnings stay, crate progress lines go
cargo_f() {
  grep -vE '^ +(Compiling|Checking|Documenting|Downloading|Downloaded|Updating|Locking|Adding|Blocking|Fresh) ' |
    awk 'NR <= 150 || /generated [0-9]+ warnings?|Finished/ { print; next }
      !c++ { print "[... warnings past 150 lines trimmed by the eetc hook ...]" }'
}

# warnings (first 60), errors and the summary; the [INFO] log goes
mvn_f() {
  grep -E '^\[(WARNING|ERROR)\]|Tests run: [0-9]+, Failures: [0-9]+, Errors: [0-9]+, Skipped: [0-9]+$|BUILD SUCCESS|Total time' |
    awk 'NR <= 60 || !/^\[WARNING\]/ { print; next }
      !c++ { print "[... more warnings trimmed by the eetc hook ...]" }'
}

# replaces each lockfile's diff with one line; other files' diffs stay
lockfile_f() {
  awk 'function flush() { if (name != "") print hdr " [eetc hook: " n "-line lockfile diff hidden; pass the lockfile as a path to see it]"; name = "" }
    /^diff --git / {
      flush()
      if ($NF ~ /(^|\/)([^\/]+\.lock|package-lock\.json|pnpm-lock\.yaml|go\.sum)$/) { hdr = $0; name = $NF; n = 0; next }
    }
    name != "" && /^([-+ @\\]|index |old mode|new mode|deleted file|new file|similarity|dissimilarity|rename |copy |Binary files)/ { n++; next }
    { flush(); print }
    END { flush() }'
}

if [[ $cmd =~ $install_re || $cmd =~ $docker_re ]]; then
  f=ends
elif [[ $cmd =~ $cargo_re ]]; then
  f=cargo_f
elif [[ $cmd =~ $mvn_re && $cmd =~ $mvn_lifecycle && ! $cmd =~ $mvn_plugin_goal ]]; then
  f=mvn_f
elif [[ $cmd =~ $git_re && ! $cmd =~ $names_lockfile && $out == *'diff --git '* ]]; then
  f=lockfile_f
else
  exit 0
fi

new_out=$($f <<<"$out")
new_err=$($f <<<"$err")
[[ $new_out == "$out" && $new_err == "$err" ]] && exit 0
# keep every other field of the Bash result, or Claude Code ignores the replacement
jq -c --arg o "$new_out" --arg e "$new_err" \
  '{hookSpecificOutput: {hookEventName: "PostToolUse", updatedToolOutput: (.tool_response | .stdout = $o | .stderr = $e)}}' <<<"$in"
