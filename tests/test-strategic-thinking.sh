#!/usr/bin/env bash
# test-strategic-thinking.sh
# Fuzzy prompt testing for strategic-thinking skill.
# Verifies trigger words and routing table coverage.
# Run from repo root: ./tests/test-strategic-thinking.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0; FAIL=0
green() { echo "  ✅ $1"; PASS=$((PASS + 1)); }
red()   { echo "  ❌ $1"; FAIL=$((FAIL + 1)); }

echo "=== Strategic-Thinking Fuzzy Prompt Tests ==="
echo ""

# ── Load skill and routing table ──
SKILL="$ROOT/skills/engineering/strategic-thinking/SKILL.md"
ROUTING="$ROOT/skills/project-workflow/references/full-skill-routing.md"

echo "1. Skill file exists"
if [ -f "$SKILL" ]; then green "strategic-thinking/SKILL.md exists"; else red "MISSING"; fi
echo ""

# ── Test: exact trigger words in routing table ──
echo "2. Exact trigger words present in routing table"
EXACT_TRIGGERS=("zoom out" "grill" "handoff" "caveman" "全景" "压力测试" "交接" "省 token" "brief")
ST_LINE=$(grep 'strategic-thinking' "$ROUTING" | head -1)
for t in "${EXACT_TRIGGERS[@]}"; do
  if echo "$ST_LINE" | grep -qi "$t"; then
    green "'$t' → strategic-thinking"
  else
    red "'$t' → NOT in strategic-thinking routing row"
  fi
done
echo ""

# ── Test: fuzzy/informal trigger phrases ──
echo "3. Fuzzy/informal phrases route to strategic-thinking"
FUZZY=(
  "给我看全景"
  "换个角度看"
  "帮我压力测试一下"
  "这个方案靠谱吗"
  "交接给下一个agent"
  "省点token"
)

for phrase in "${FUZZY[@]}"; do
  MATCHED=false
  # Dynamically extract all comma-separated keywords from the strategic-thinking routing line
  TRIGGER_LINE=$(grep 'strategic-thinking' "$ROUTING" | head -1)
  # Extract the second column (keywords) between the first and second | separator
  KWS=$(echo "$TRIGGER_LINE" | awk -F'|' '{print $2}' | tr ',' '\n')
  while IFS= read -r kw; do
    kw=$(echo "$kw" | xargs)  # trim whitespace
    [ -z "$kw" ] && continue
    if echo "$phrase" | grep -qi "$kw"; then
      MATCHED=true
      break
    fi
  done <<< "$KWS"
  if $MATCHED; then
    green "'$phrase' → routes to strategic-thinking"
  else
    red "'$phrase' → NO MATCH in routing table"
  fi
done
echo ""

# ── Test: non-trigger prompts should NOT route ──
echo "4. Non-trigger prompts do NOT route to strategic-thinking"
NON_TRIGGERS=(
  "把这个变量改成userCount"
  "跑一下go test"
  "为什么这个函数返回nil"
  "帮我写个README"
  "数据库加个索引"
)
for prompt in "${NON_TRIGGERS[@]}"; do
  TRIGGERED=false
  for kw in 全景 压力测试 交接 "省 token" brief "zoom out" grill handoff caveman "思维模式" "切换模式" "broader context" "unfamiliar code"; do
    if echo "$prompt" | grep -qi "$kw"; then
      TRIGGERED=true
      break
    fi
  done
  if $TRIGGERED; then
    red "'$prompt' → FALSE POSITIVE (should NOT trigger)"
  else
    green "'$prompt' → correctly ignored"
  fi
done
echo ""

# ── Test: mode priority (Caveman > Zoom-Out > Grill > Handoff) ──
echo "5. Mode priority order in SKILL.md"
# Check all 4 modes are listed
for mode in "Caveman" "Zoom-Out" "Grill" "Handoff"; do
  if grep -q "$mode" "$SKILL"; then
    green "Mode '$mode' defined in skill"
  else
    red "Mode '$mode' MISSING from skill"
  fi
done

# Check Caveman is first in decision tree (persistence makes it highest priority)
CAVEMAN_LINE=$(grep -n 'caveman.*省 token.*brief' "$SKILL" | head -1 | cut -d: -f1)
ZOOM_LINE=$(grep -n 'zoom out.*全景.*big picture' "$SKILL" | head -1 | cut -d: -f1)
GRILL_LINE=$(grep -n 'grill.*压力测试.*方案行不行' "$SKILL" | head -1 | cut -d: -f1)
HANDOFF_LINE=$(grep -n 'handoff.*交接.*换 agent' "$SKILL" | head -1 | cut -d: -f1)

if [ -n "$CAVEMAN_LINE" ] && [ -n "$ZOOM_LINE" ] && [ "$CAVEMAN_LINE" -lt "$ZOOM_LINE" ]; then
  green "Caveman ($CAVEMAN_LINE) comes before Zoom-Out ($ZOOM_LINE)"
else
  red "Priority order wrong: Caveman should be first"
fi

if [ -n "$ZOOM_LINE" ] && [ -n "$GRILL_LINE" ] && [ "$ZOOM_LINE" -lt "$GRILL_LINE" ]; then
  green "Zoom-Out ($ZOOM_LINE) comes before Grill ($GRILL_LINE)"
else
  red "Priority order wrong: Zoom-Out should be before Grill"
fi

if [ -n "$GRILL_LINE" ] && [ -n "$HANDOFF_LINE" ] && [ "$GRILL_LINE" -lt "$HANDOFF_LINE" ]; then
  green "Grill ($GRILL_LINE) comes before Handoff ($HANDOFF_LINE)"
else
  red "Priority order wrong: Grill should be before Handoff"
fi
echo ""

# ── Test: decision tree has NO MATCH → normal mode ──
echo "6. Decision tree has default exit (NO MATCH → normal mode)"
if grep -q "NO MATCH" "$SKILL" && grep -q "正常模式" "$SKILL"; then
  green "NO MATCH → normal mode path exists"
else
  red "NO MATCH path MISSING"
fi
echo ""

# ── Test: mode mutual exclusion rules ──
echo "7. Mode mutual exclusion rules"
if grep -q "Grill.*不能同时.*Zoom-Out\|Zoom-Out.*不能同时.*Grill" "$SKILL"; then
  green "Grill/Zoom-Out mutual exclusion defined"
else
  red "Grill/Zoom-Out mutual exclusion MISSING"
fi
if grep -q "暂停.*Caveman" "$SKILL"; then
  green "Caveman pause-on-mode-switch defined"
else
  red "Caveman pause-on-mode-switch MISSING"
fi
echo ""

# ── Test: one-shot listing for ambiguous intent ──
echo "8. One-shot mode listing for ambiguous intent"
if grep -q "一次性列出.*4.*选项" "$SKILL"; then
  green "One-shot listing rule present"
else
  red "One-shot listing rule MISSING"
fi
echo ""

# ── Summary ──
echo "========================================="
echo "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -eq 0 ]; then
  echo "✅ ALL STRATEGIC-THINKING TESTS PASSED"
  exit 0
else
  echo "❌ $FAIL CHECK(S) FAILED"
  exit 1
fi
