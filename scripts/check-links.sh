#!/bin/bash
# 链接完整性检查 - CI 用
# 返回 0 = 全部通过，1 = 有链接失效

set -uo pipefail

FAILED=0; SOFT404=0; TOTAL=0

msg() { echo "[$(date +%H:%M:%S)] $*"; }

check_url() {
  local url="$1" file="$2" lineno="$3"
  local tmpf result http_code content_type title
  tmpf=$(mktemp)
  result=$(curl -s -L --connect-timeout 6 --max-time 12 \
    -o "$tmpf" -w "%{http_code}|||%{content_type}" "$url" 2>/dev/null) || true
  http_code=$(echo "$result" | cut -d'|' -f1)
  content_type=$(echo "$result" | cut -d'|' -f3)

  if [ "$http_code" = "000" ] || [ -z "$http_code" ]; then
    echo "❌ ERR 连接失败    $file:$lineno  $url"
    FAILED=$((FAILED + 1)); rm -f "$tmpf"; return
  fi

  # 软 404（仅 HTML，跳过 PDF）
  if ! echo "$content_type" | grep -qi "pdf"; then
    title=$(grep -oP "(?<=<title>)[^<]+" "$tmpf" 2>/dev/null | head -1)
    if echo "$title" | grep -qiP "(404|not.?found|page.?not|不存在|未找到|sorry|oops|not available|not be found)"; then
      echo "⚠️ 软404 $http_code  $file:$lineno  title=[$title]  $url"
      SOFT404=$((SOFT404 + 1)); rm -f "$tmpf"; return
    fi
  fi
  rm -f "$tmpf"

  case "$http_code" in
    200|301|302|403|202) ;;
    404) echo "❌ 404        $file:$lineno  $url"; FAILED=$((FAILED + 1)) ;;
    *)   echo "❌ $http_code    $file:$lineno  $url"; FAILED=$((FAILED + 1)) ;;
  esac
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

msg "开始检查链接..."

# 用 while read + 进程替代而不是管道，避免 subshell 问题
while IFS= read -r f; do
  [ -z "$f" ] && continue
  while IFS=: read -r lineno line; do
    url=$(echo "$line" | grep -oP '\]\(\K[^)]+' | head -1)
    [ -z "$url" ] && url=$(echo "$line" | grep -oP 'https?://[a-zA-Z0-9./?_=%&;+:\-]+' | head -1)
    [ -z "$url" ] && continue
    echo "$url" | grep -q "github.com/DslsDZC/kernel-design-book" && continue
    echo "$url" | grep -q "^#" && continue
    TOTAL=$((TOTAL + 1))
    check_url "$url" "$(basename "$f")" "$lineno"
  done < <(grep -n 'http' "$f" 2>/dev/null || true)
done < <(find "$REPO_DIR" -maxdepth 2 -name '*.md' \
  -not -path '*/node_modules/*' \
  -not -path '*/.git/*' \
  -not -name 'book.md' \
  -not -name 'CLAUDE.md' \
  -not -name 'README.md' \
  | sort)

msg "----"
msg "检查完成: $TOTAL 个链接"
if [ "$FAILED" -gt 0 ]; then
  msg "❌ $FAILED 个链接失效"
  exit 1
elif [ "$SOFT404" -gt 0 ]; then
  msg "⚠️  $SOFT404 个软 404（需人工确认）"
  exit 0
else
  msg "✅ 全部通过"
  exit 0
fi
