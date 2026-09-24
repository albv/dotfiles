#!/bin/bash
input=$(cat)
# Without jq there's nothing to parse with: show a bare label, not errors.
command -v jq >/dev/null 2>&1 || { printf '\033[2mClaude\033[0m'; exit 0; }
# One jq pass. The context math lives here, where a missing, zero, fractional
# or non-numeric field can't trip shell arithmetic. total_input_tokens =
# tokens currently in context (input + cache), the same sum /context shows.
# Current-context semantics need CC >= 2.1.132; before that the field was a
# cumulative session total. Fields are joined with \x1f, not tab: tab is IFS
# whitespace, so an empty field would collapse and shift the rest.
# POSIX only below (heredoc, not `< <(…)` or $'…'): Claude Code runs this via
# /bin/sh, which ignores the shebang and rejects bash-only syntax.
fields=$(printf '%s' "$input" | jq -r '
  def pos: if type == "number" and . > 0 then floor else 0 end;
  (.context_window.context_window_size | pos | if . == 0 then 200000 else . end) as $size
  | (.context_window.total_input_tokens | pos) as $used
  | [ (.model.display_name | if type == "string" and . != "" then . else "Claude" end),
      (if $used > 0
       then "\($used / 1000 | floor)k/\($size / 1000 | floor)k (\($used * 100 / $size | floor)%)"
       else "–/\($size / 1000 | floor)k" end),
      (.workspace.current_dir | if type == "string" then . else "" end)
    ] | join("\u001f")' 2>/dev/null)
IFS=$(printf '\037') read -r model context_info cwd <<EOF
$fields
EOF
[ -n "$model" ] || model="Claude"   # unparseable input
[ -n "$context_info" ] || context_info="–"
if [ -n "$cwd" ]; then
  project=$(basename "$cwd")
  # git -C: works from any subdirectory of a repo (or worktree), not just its root
  branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null ||
           git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
else
  project="~"
  branch=""
fi
git_info=${branch:+ on $branch}
printf "\033[2m%s | %s | %s%s\033[0m" "$model" "$context_info" "$project" "$git_info"
