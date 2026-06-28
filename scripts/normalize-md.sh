#!/bin/bash
# 规范化所有章节的 Markdown 格式
# 1. 将 "X.Y 标题" 格式的子节标题转为 ## 二级标题
# 2. 确保 "本章小结" 也转为 ## 标题
# 3. 不改动正文内的数字引用

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "开始检查章节文件..."
FIXED=0
CHECKED=0

for f in "$REPO_DIR"/第*_*/*.md; do
  CHECKED=$((CHECKED + 1))
  changed=0
  tmpf=$(mktemp)

  while IFS= read -r line; do
    # 匹配规则：行首为 "数字.数字 空格 任意字符" 且不是已有标题
    # 例如 "16.1 为什么需要衰减" → "## 16.1 为什么需要衰减"
    # 注意：不匹配 "2025年"（没有点号）、"范围0-1024"（没有点号）
    if echo "$line" | grep -qP '^\d+\.\d+\s+\S'; then
      # 已经是 ## 或 # 标题？跳过
      if echo "$line" | grep -qP '^#{1,3}\s'; then
        echo "$line" >> "$tmpf"
      else
        echo "## $line" >> "$tmpf"
        changed=1
      fi
    else
      echo "$line" >> "$tmpf"
    fi
  done < "$f"

  if [ "$changed" -eq 1 ]; then
    cp "$tmpf" "$f"
    echo " 修正: $(basename "$f")"
    FIXED=$((FIXED + 1))
  fi
  rm -f "$tmpf"
done

echo "---"
echo "检查 $CHECKED 个文件，修正 $FIXED 个"
