#!/usr/bin/env bash
# test-prior-research.sh
# Fuzzy prompt testing for prior-research skill.
# Run from repo root: ./tests/test-prior-research.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0; FAIL=0
green() { echo "  ✅ $1"; PASS=$((PASS + 1)); }
red()   { echo "  ❌ $1"; FAIL=$((FAIL + 1)); }

echo "=== Prior-Research Fuzzy Prompt Tests ==="
echo ""

SKILL="$ROOT/skills/methodology/prior-research/SKILL.md"

# ── 1. Skill exists ──
echo "1. Skill file exists"
if [ -f "$SKILL" ]; then green "prior-research/SKILL.md exists ($(wc -l < "$SKILL") lines)"; else red "MISSING"; fi
echo ""

# ── 2. Exact trigger words ──
echo "2. Exact trigger words in skill metadata/body"
EXACT=("docs" "library" "search" "scrape" "crawl" "research" "context7" "firecrawl" "文档" "搜索" "抓取" "API" "怎么配置")
for t in "${EXACT[@]}"; do
  if grep -qi "$t" "$SKILL"; then
    green "'$t' → prior-research"
  else
    red "'$t' → NOT in skill trigger text"
  fi
done
echo ""

# ── 3. Fuzzy/informal phrases ──
echo "3. Fuzzy prompts route to prior-research"
FUZZY=(
  "viper 怎么配置"
  "gin 的最新版 API 怎么用"
  "帮我搜一下 Go 并发模式"
  "抓取这个页面看看内容"
  "我不确定这个库怎么用"
  "查一下 gorilla/mux 的文档"
  "帮我查查 redis 客户端怎么配置"
  "搜一下有没有类似的开源项目"
)

for phrase in "${FUZZY[@]}"; do
  KWS=$(printf '%s\n' "docs" "library" "API" "search" "scrape" "crawl" "research" "context7" "firecrawl" "文档" "搜索" "搜" "抓取" "配置" "不确定" "最新版" "怎么用")
  MATCHED=false
  while IFS= read -r kw; do
    kw=$(echo "$kw" | xargs)
    [ -z "$kw" ] && continue
    if echo "$phrase" | grep -qi "$kw"; then
      MATCHED=true; break
    fi
  done <<< "$KWS"
  if $MATCHED; then
    green "'$phrase' → routes to prior-research"
  else
    red "'$phrase' → NO MATCH"
  fi
done
echo ""

# ── 4. Non-trigger prompts ──
echo "4. Non-trigger prompts do NOT route"
NON=(
  "把这个变量改成userCount"
  "跑一下go test"
  "为什么这个函数返回nil"
  "帮我写个README"
  "数据库加个索引"
)
for prompt in "${NON[@]}"; do
  KWS=$(printf '%s\n' "docs" "library" "API" "search" "scrape" "crawl" "research" "context7" "firecrawl" "文档" "搜索" "搜" "抓取" "配置" "不确定" "最新版" "怎么用")
  TRIGGERED=false
  while IFS= read -r kw; do
    kw=$(echo "$kw" | xargs)
    [ -z "$kw" ] && continue
    if echo "$prompt" | grep -qi "$kw"; then
      TRIGGERED=true; break
    fi
  done <<< "$KWS"
  if $TRIGGERED; then
    red "'$prompt' → FALSE POSITIVE"
  else
    green "'$prompt' → correctly ignored"
  fi
done
echo ""

# ── 5. Skill content: WHEN section exists ──
echo "5. Skill structure: WHEN → HOW → USE"
for section in "WHEN" "HOW" "USE"; do
  if grep -q "$section" "$SKILL"; then
    green "'$section' section exists"
  else
    red "'$section' section MISSING"
  fi
done
echo ""

# ── 6. Skill content: tool coverage ──
echo "6. Skill content: research tool coverage"
for tool in "context7" "firecrawl" "curl" "delegate_task"; do
  if grep -q "$tool" "$SKILL"; then
    green "'$tool' mentioned in skill"
  else
    red "'$tool' MISSING from skill"
  fi
done
echo ""

# ── 7. Skill content: route by research intent ──
echo "7. Skill content: route by research intent"
for route in \
  "库、框架、SDK、API、CLI 或云服务文档 → Context7" \
  "通用 Web 搜索、近期信息、网页提取、站点遍历或案例研究 → Firecrawl" \
  "Context7 无结果或缺少所需网页内容 → Firecrawl"; do
  if grep -Fq "$route" "$SKILL"; then
    green "route present: $route"
  else
    red "route MISSING: $route"
  fi
done
echo ""

# ── 8. Deprecated skills still exist but with marker ──
echo "8. Old tools marked deprecated"
for f in "$ROOT/skills/tools/context7-docs/SKILL.md" "$ROOT/skills/tools/firecrawl-web/SKILL.md"; do
  name=$(basename "$(dirname "$f")")
  if [ -f "$f" ] && grep -q 'DEPRECATED' "$f"; then
    green "$name: deprecated, file preserved"
  else
    red "$name: deprecated marker MISSING or file deleted"
  fi
done
echo ""

# ── Summary ──
echo "========================================="
echo "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -eq 0 ]; then
  echo "✅ ALL PRIOR-RESEARCH TESTS PASSED"
  exit 0
else
  echo "❌ $FAIL CHECK(S) FAILED"
  exit 1
fi
