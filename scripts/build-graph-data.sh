#!/bin/bash
# 生成知识图谱数据（章节交叉引用 JSON）
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DATA_FILE="$REPO_DIR/book-site/src/graph-data.json"

mkdir -p "$REPO_DIR/book-site/src"

python3 -c "
import os, re, json, glob

repo = '$REPO_DIR'
nodes = []
edges = []
chapter_titles = {}
chapter_parts = {}

# 部分映射
part_names = {
    range(1,5): '第1部分 总起',
    range(5,10): '第2部分 资源',
    range(10,22): '第3部分 权限',
    range(22,51): '第4部分 调度',
    range(51,64): '第5部分 结构',
    range(64,68): '第6部分 打破模型',
    range(68,80): '第7部分 架构与实现',
    range(80,86): '第8部分 经典设计',
}

for f in sorted(glob.glob(f'{repo}/第*_*/*.md')):
    m = re.search(r'(\d+)_(.+?)\.md', os.path.basename(f))
    if not m: continue
    ch_num = int(m.group(1))
    ch_slug = m.group(2)

    # 提取标题
    with open(f) as fh:
        first = fh.readline().strip()
    title = first.lstrip('# ')
    chapter_titles[ch_num] = title

    # 所属部分
    for rng, name in part_names.items():
        if ch_num in rng:
            chapter_parts[ch_num] = name
            break

    nodes.append({
        'id': ch_num,
        'label': f'第{ch_num}章',
        'title': title,
        'part': chapter_parts.get(ch_num, ''),
        'slug': ch_slug,
    })

    # 交叉引用
    with open(f) as fh:
        for line in fh:
            if line.strip().startswith('#'): continue
            for m2 in re.finditer(r'第(\d+)章(?!\s)', line):
                to_ch = int(m2.group(1))
                if to_ch != ch_num and 1 <= to_ch <= 85:
                    edges.append({
                        'source': ch_num,
                        'target': to_ch,
                    })

data = {'nodes': nodes, 'edges': edges}
os.makedirs(os.path.dirname('$DATA_FILE'), exist_ok=True)
with open('$DATA_FILE', 'w') as f:
    json.dump(data, f, ensure_ascii=False)

print(f'[OK] 图谱数据已生成: {len(nodes)} 节点, {len(edges)} 条边')
" 2>&1
