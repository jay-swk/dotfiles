#!/usr/bin/env bash
# Claude Code statusLine — 이모지 게이지 + tmux 연동
input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name // "Claude"')
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
used=$(echo "$input" | jq -r '.context_window.used_percentage // 0')
in_tok=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
out_tok=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
five=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // 0')

ctx_pct=$(printf "%.0f" "$used")
rate_pct=$(printf "%.0f" "$five")
in_k=$((in_tok / 1000))
out_k=$((out_tok / 1000))
cost_fmt=$(printf "%.2f" "$cost")

# 컨텍스트 게이지 (5칸)
filled=$((ctx_pct / 20))
empty=$((5 - filled))
bar=$(printf '█%.0s' $(seq 1 $filled 2>/dev/null) 2>/dev/null)$(printf '░%.0s' $(seq 1 $empty 2>/dev/null) 2>/dev/null)

# 상태 아이콘
[ "$ctx_pct" -ge 80 ] 2>/dev/null && ctx_icon="🔴" || { [ "$ctx_pct" -ge 50 ] 2>/dev/null && ctx_icon="🟡" || ctx_icon="🟢"; }
[ "$rate_pct" -ge 80 ] 2>/dev/null && rate_icon="🔴" || { [ "$rate_pct" -ge 50 ] 2>/dev/null && rate_icon="🟡" || rate_icon="🟢"; }

# tmux 상태바용 파일 저장 (색상 없이)
printf " %s │ ctx:%s%% │ ↑%sK ↓%sK │ \$%s │ 5h:%s%%" \
  "$model" "$ctx_pct" "$in_k" "$out_k" "$cost_fmt" "$rate_pct" \
  > "$HOME/.claude/tmux-status" 2>/dev/null || true

# Claude Code UI 출력
echo "🧠 ${model} ┃ ${ctx_icon} ${bar} ${ctx_pct}% ┃ 📊 ↑${in_k}K ↓${out_k}K ┃ 💰 \$${cost_fmt} ┃ ⏱️ ${rate_icon} 5h:${rate_pct}%"
