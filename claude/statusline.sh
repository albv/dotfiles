#!/bin/bash
input=$(cat)
model=$(echo "$input" | jq -r '.model.display_name // "Claude"')
context_size=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
context_k=$((context_size / 1000))
# total_input_tokens = tokens currently in context (input + cache), the
# same sum /context shows. Current-context semantics need CC >= 2.1.132;
# before that the field was a cumulative session total.
used_tokens=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
if [ "$used_tokens" -gt 0 ] 2>/dev/null; then
  used_k=$((used_tokens / 1000))
  used_pct=$((used_tokens * 100 / context_size))
  context_info="${used_k}k/${context_k}k (${used_pct}%)"
else
  context_info="–/${context_k}k"
fi
cwd=$(echo "$input" | jq -r '.workspace.current_dir // ""')
if [ -n "$cwd" ]; then
  project=$(basename "$cwd")
else
  project="~"
fi
if [ -n "$cwd" ] && [ -e "$cwd/.git" ]; then
  branch=$(cd "$cwd" && git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
  if [ -n "$branch" ]; then
    git_info=" on $branch"
  else
    git_info=""
  fi
else
  git_info=""
fi
printf "\033[2m%s | %s | %s%s\033[0m" "$model" "$context_info" "$project" "$git_info"
