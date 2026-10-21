#!/bin/bash
# PreToolUse hook for Bash: trims pytest / Django / Maven / cargo test output to
# failures + summary to save context. The rewritten command is auto-approved, so
# the hook fails closed: it only touches a plain test command whose every
# argument is a known, side-effect-free flag or a test path inside the project.
# Anything else (chained, substituted, redirected, an unknown flag, another
# goal) passes through unchanged to the normal permission flow.
cmd=$(jq -r '.tool_input.command // ""')
pass() { echo '{}'; exit 0; }

venv='source .venv/bin/activate && '
c=${cmd#"$venv"}
# a shell word: unquoted safe chars, or quoted strings with nothing expandable inside
u='[][A-Za-z0-9_./:=,+@#*?~-]'
q="'[^'"$'\n'"]*'|\"[^\"\$\`\\"$'\n'"]*\""
word="(${u}|${q})+"
all="^(${u}|${q}| )*\$"
comment="(^| )[\"']?#"
[[ $c =~ $all && ! $c =~ $comment && $c != *..* ]] || pass

# a relative path or test name, optionally quoted
path="[\"']?[A-Za-z0-9_*].*"
# every word is a bare flag ($1), a flag ($2) plus the value after it, or a
# positional ($3, default: $path); at least $4 positionals
args_ok() {
  local rest=$args w want= n=0 lead="^ *(${word})" bare="^($1)\$" valued="^($2)\$" pos="^(${3:-$path})\$"
  while [[ $rest =~ $lead ]]; do
    w=${BASH_REMATCH[1]} rest=${rest:${#BASH_REMATCH[0]}}
    if [[ -n $want ]]; then want=
    elif [[ $w =~ $valued ]]; then want=1
    elif [[ $w =~ $bare ]]; then :
    elif [[ $w =~ $pos ]]; then n=$((n + 1))
    else return 1
    fi
  done
  [[ -z $want && $n -ge ${4:-0} ]]
}

pytest_re='^((uv|poetry) run )?(python -m )?pytest( |$)'
django_re='^(poetry run )?python manage\.py test( |$)'
cargo_re='^cargo (\+[A-Za-z0-9._-]+ )?(test|nextest run)( |$)'
mvn_re='^mvn( |$)'

# FAILED/ERROR blocks (at most 200 lines) plus the last t lines, without a temp file
keep='$0 ~ re { n = a + 1 } n && n-- && shown++ < 200; { last[NR % t] = $0 } END { for (i = NR - t + 1; i <= NR; i++) if (i > 0) print last[i % t] }'
# passing tests, build progress and blank lines; failures, compile errors and summaries stay
cargo_noise='^test .* \.\.\. (ok|ignored.*)$|^ +(Compiling|Checking|Downloading|Downloaded|Updating|Locking|Adding|Blocking|PASS|START) |^running [0-9]+ tests?$|^$'

if [[ $c =~ $pytest_re ]]; then
  args=${c:${#BASH_REMATCH[0]}}
  args_ok '-[qvxsl]+|-r[A-Za-z]+|-n[0-9]+|--(lf|ff|nf|sw|last-failed|failed-first|new-first|stepwise|exitfirst|quiet|verbose|showlocals|no-header|no-summary|co|collect-only|strict-markers|disable-warnings|cov|no-cov)|--(maxfail|tb|durations|color|cov)=.+|--cov-report=term(-missing)?' \
    '-k|-m|-n|--maxfail|--tb|--durations' || pass
  new="$cmd 2>&1 | awk -v re='^(FAILED|ERROR)' -v a=20 -v t=6 '$keep'"
elif [[ $c =~ $django_re ]]; then
  args=${c:${#BASH_REMATCH[0]}}
  args_ok '-v[0-3]|--verbosity=[0-3]|--failfast|--keepdb|--noinput|--no-input|--parallel(=[a-z0-9]+)?|--timing|--shuffle(=[0-9]+)?|--reverse|-r|-b|--buffer|-d|--debug-sql|--debug-mode|--durations=[0-9]+|--force-color|--no-color' \
    '-v|--verbosity|-k|--tag|--exclude-tag|--durations' || pass
  new="$cmd 2>&1 | awk -v re='^(FAIL|ERROR):' -v a=15 -v t=4 '$keep'"
elif [[ $c =~ $cargo_re ]]; then
  args=${c:${#BASH_REMATCH[0]}}
  # cargo flags, then test-harness flags after `--`
  args_ok '--|--release|--workspace|--all|--lib|--bins|--tests|--doc|--all-targets|--all-features|--no-default-features|--no-fail-fast|--no-run|--locked|--offline|--frozen|-q|--quiet|-v|-vv|--verbose|-j[0-9]+|--(package|features|test|bin|jobs|exclude|test-threads|skip|color|retries)=.+|--nocapture|--no-capture|--ignored|--include-ignored|--exact|--show-output' \
    '-p|--package|-F|--features|--test|--bin|-j|--jobs|--exclude|-E|--filterset|--test-threads|--skip|--color|--retries' || pass
  new="$cmd 2>&1 | grep -vE '$cargo_noise' | awk 'NR <= 250 || /^ *(test result|Summary|error)/'"
elif [[ $c =~ $mvn_re ]]; then
  args=${c:${#BASH_REMATCH[0]}}
  # only the test / verify phases: no other phase (clean, package, install,
  # deploy, site...), no plugin:goal, no profile, no arbitrary -D property
  args_ok '-q|-e|-X|-B|-o|-U|-ntp|-fae|-ff|-am|-amd|--(quiet|errors|debug|batch-mode|offline|update-snapshots|no-transfer-progress|fail-at-end|fail-fast|also-make|also-make-dependents)|-T[0-9.]+C?|-D(test|it\.test|skipTests|skipITs|maven\.test\.skip|groups|excludedGroups|failIfNoTests|surefire\.failIfNoSpecifiedTests|maven\.test\.failure\.ignore)(=.*)?' \
    '-T|--threads|-pl|--projects|-rf|--resume-from' 'test|verify' 1 || pass
  new=$cmd
  [[ $c == *-ntp* || $c == *--no-transfer-progress* ]] || new=${cmd/mvn/mvn --no-transfer-progress}
else
  pass
fi
jq -n --arg c "$new" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "allow", updatedInput: {command: $c}}}'
