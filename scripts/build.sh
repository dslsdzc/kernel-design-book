#!/bin/bash

set -e

OUTPUT="${1:-book.md}"

DATE=$(git log -1 --format=%cd --date=format:%Y年%m月 2>/dev/null || date +%Y年%m月)

> "$OUTPUT"

cat >> "$OUTPUT" << EOF
---
title: 如何设计内核：权限、调度与结构
author: DslsDZC
date: ${DATE}
---

EOF

if [ -f "引言.txt" ]; then
    cat "引言.txt" >> "$OUTPUT"
    echo "" >> "$OUTPUT"
    echo "" >> "$OUTPUT"
fi

for part_dir in $(ls -d 第*部分_*/ 2>/dev/null | sort -V); do
    part_num=$(echo "$part_dir" | grep -oE '[0-9]+' | head -1)
    part_name=$(echo "$part_dir" | sed 's/^第[0-9]*部分_//' | sed 's/\/$//')
    echo "# 第${part_num}部分 ${part_name}" >> "$OUTPUT"
    echo "" >> "$OUTPUT"

    for ch_file in $(ls "$part_dir"/*.md 2>/dev/null | sort -V); do
        cat "$ch_file" >> "$OUTPUT"
        echo "" >> "$OUTPUT"
        echo "" >> "$OUTPUT"
    done
done

echo "合并完成: $OUTPUT"
