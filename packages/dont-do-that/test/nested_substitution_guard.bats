#!/usr/bin/env bats

DISPATCH="$BATS_TEST_DIRNAME/../hooks/dispatch.sh"

run_guard() {
  local payload
  payload=$(jq -cn --arg cmd "$1" '{hook_event_name:"PreToolUse", tool_name:"Bash", cwd:"/tmp", tool_input:{command:$cmd}}')
  run bash -c 'printf "%s" "$1" | DD_AGENT="$3" DD_ONLY_PRETOOLUSE_GUARDS=nested-substitution bash "$2"' _ "$payload" "$DISPATCH" "${2:-claude}"
}

@test "denies a substitution nested inside a quoted substitution" {
  run_guard 'for b in a c; do r=$(git rev-parse -q --verify origin/$b); l=$(git rev-parse $b); echo "$b: $([ -z "$r" ] && echo NO-REMOTE || ([ "$r" = "$l" ] && echo in-sync || echo "differs, local-only=$(git rev-list --count origin/$b..$b)"))"; done'
  [ "$status" -eq 2 ]
  [[ "$output" == *"[dont-do-that/nested-substitution]"* ]]
}

@test "denies a bare nested substitution" {
  run_guard 'git log $(git merge-base $(git rev-parse HEAD) main)..HEAD'
  [ "$status" -eq 2 ]
}

@test "denies nesting after arithmetic inside a substitution" {
  run_guard 'echo "$(echo $((1+2)) $(date))"'
  [ "$status" -eq 2 ]
}

@test "denies a substitution inside arithmetic inside a substitution" {
  run_guard 'echo "$(echo $(( $(date +%s) + 1 )))"'
  [ "$status" -eq 2 ]
}

@test "denies nesting after a case statement inside a substitution" {
  run_guard 'echo "$(case x in x) echo ok;; esac; echo $(date))"'
  [ "$status" -eq 2 ]
}

@test "passes a case statement inside a single substitution" {
  run_guard 'echo "$(case x in (x) echo ok;; *) echo no;; esac)"; echo $(date)'
  [ "$status" -eq 0 ]
}

@test "passes the word case as an argument" {
  run_guard 'echo "$(echo case x)" "$(date)"'
  [ "$status" -eq 0 ]
}

@test "denies nesting after a subshell inside a substitution" {
  run_guard 'echo "$( (echo x); echo $(date))"'
  [ "$status" -eq 2 ]
}

@test "denies nesting on the rest of a heredoc opener line" {
  run_guard "$(printf '%s\n' "cat <<'EOF'; echo \$(echo \$(date))" 'hello' 'EOF')"
  [ "$status" -eq 2 ]
}

@test "passes nesting inside a shell comment" {
  run_guard "$(printf '%s\n' '# $(outer $(inner))' 'echo ok')"
  [ "$status" -eq 0 ]
}

@test "passes sequential substitutions" {
  run_guard 'for b in a c; do u=$(git cherry main "$b" | grep -c "^+"); echo "$b $u $(git rev-parse --short "$b")"; done'
  [ "$status" -eq 0 ]
}

@test "passes arithmetic inside a substitution" {
  run_guard 'echo "$(seq $((1 + 2)))"'
  [ "$status" -eq 0 ]
}

@test "passes nesting inside single quotes" {
  run_guard "echo '\$(a \$(b))'"
  [ "$status" -eq 0 ]
}

@test "passes a script written through a quoted heredoc" {
  run_guard "$(printf '%s\n' "cat > x.sh <<'EOF'" 'echo "$(date "$(cat fmt)")"' 'EOF' 'bash x.sh')"
  [ "$status" -eq 0 ]
}

@test "passes a commit message heredoc inside a substitution" {
  run_guard "$(printf '%s\n' 'git commit -m "$(cat <<'"'"'EOF'"'"'' 'Subject' '' 'Body mentions $(nested $(text)).' 'EOF' ')"')"
  [ "$status" -eq 0 ]
}

@test "passes with the allow marker" {
  run_guard 'echo "$(a "$(b)")" # allow-nested-substitution'
  [ "$status" -eq 0 ]
}

@test "stays off for codex" {
  run_guard 'echo "$(a "$(b)")"' codex
  [ "$status" -eq 0 ]
}
