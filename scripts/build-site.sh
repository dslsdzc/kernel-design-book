#!/bin/bash
# 构建 Rspress 静态网站（全自动，新增章节自动发现）
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SITE_DIR="$REPO_DIR/book-site"
DOCS_DIR="$SITE_DIR/docs"

# 部分列表（有序）
PARTS=(
  "part1-overview:第1部分 总起：内核需要干嘛:第1部分_总起-内核需要干嘛"
  "part2-resources:第2部分 资源：内核管理的对象:第2部分_资源-内核管理的对象"
  "part3-permissions:第3部分 权限模型：谁可以用:第3部分_权限模型-谁可以用"
  "part4-scheduling:第4部分 调度模型：资源什么时候给谁用多久:第4部分_调度模型-资源什么时候给谁用多久"
  "part5-structure:第5部分 结构模型：内核如何组织自己:第5部分_结构模型-内核如何组织自己"
  "part6-design:第6部分 打破模型：设计你自己的内核:第6部分_打破模型-设计你自己的内核"
  "part7-arch:第7部分 架构与实现：从模型到运行的内核:第7部分_架构与实现-从模型到运行的内核"
  "part8-classic:第8部分 经典内核设计选择:第8部分_经典内核设计选择"
)

rm -rf "$DOCS_DIR"
mkdir -p "$DOCS_DIR"

# 知识图谱页
cat > "$DOCS_DIR/graph.mdx" << 'EOF'
# 章节关系图

85 章之间的交叉引用可视化。每个节点代表一章，连线表示引用关系。

import ChapterGraph from '../src/ChapterGraph';

<ChapterGraph />
EOF

# 首页
cat > "$DOCS_DIR/index.md" << 'EOF'
---
pageType: home
hero:
  name: 如何设计内核
  text: 权限、调度与结构
  tagline: 从零理解操作系统内核设计的三个基本模型
  actions:
    - theme: brand
      text: 开始阅读
      link: /part1-overview/
    - theme: alt
      text: GitHub
      link: https://github.com/dslsdzc/kernel-design-book
features:
  - title: 权限模型
    details: 谁可以用？允许还是禁止？权限从哪里来、如何传递、如何撤销？
  - title: 调度模型
    details: 资源什么时候给谁、用多久？公平与效率如何取舍？
  - title: 结构模型
    details: 内核如何组织自己？模块如何连接、消息如何路由？
EOF

# 用 Python 生成所有 JSON（避免 shell 的 JSON 转义问题）
export REPO_DIR
python3 -c "
import json, os, re, glob

repo = os.environ['REPO_DIR']
parts = [
    ('part1-overview', '第1部分 总起：内核需要干嘛', '第1部分_总起-内核需要干嘛'),
    ('part2-resources', '第2部分 资源：内核管理的对象', '第2部分_资源-内核管理的对象'),
    ('part3-permissions', '第3部分 权限模型：谁可以用', '第3部分_权限模型-谁可以用'),
    ('part4-scheduling', '第4部分 调度模型：资源什么时候给谁用多久', '第4部分_调度模型-资源什么时候给谁用多久'),
    ('part5-structure', '第5部分 结构模型：内核如何组织自己', '第5部分_结构模型-内核如何组织自己'),
    ('part6-design', '第6部分 打破模型：设计你自己的内核', '第6部分_打破模型-设计你自己的内核'),
    ('part7-arch',  '第7部分 架构与实现：从模型到运行的内核', '第7部分_架构与实现-从模型到运行的内核'),
    ('part8-classic', '第8部分 经典内核设计选择', '第8部分_经典内核设计选择'),
]

docs = os.path.join(repo, 'book-site', 'docs')

# 根 _meta.json
root_meta = [{'type': 'file', 'name': 'graph', 'label': '章节关系图'}]
for dir_name, title, _ in parts:
    root_meta.append({'type': 'dir', 'name': dir_name, 'label': title})
with open(os.path.join(docs, '_meta.json'), 'w') as f:
    json.dump(root_meta, f, ensure_ascii=False, indent=2)

for dir_name, title, src_dir in parts:
    part_doc = os.path.join(docs, dir_name)
    src_path = os.path.join(repo, src_dir)
    os.makedirs(part_doc, exist_ok=True)

    # 部分首页
    with open(os.path.join(part_doc, 'index.md'), 'w') as f:
        f.write(f'# {title}\n')

    # 遍历章节文件
    ch_meta = []
    for ch_file in sorted(os.listdir(src_path)):
        if not ch_file.endswith('.md'): continue
        slug = re.sub(r'^\d+_', '', ch_file[:-3])
        with open(os.path.join(src_path, ch_file)) as f:
            content = f.read()
        with open(os.path.join(part_doc, f'{slug}.md'), 'w') as f:
            f.write(content)
        ch_meta.append(slug)

    # 章节 _meta.json
    with open(os.path.join(part_doc, '_meta.json'), 'w') as f:
        json.dump(ch_meta, f, ensure_ascii=False, indent=2)

# 导出图谱数据
graph_data = {'nodes': [], 'edges': []}
all_edges = set()

for f2 in sorted(glob.glob(os.path.join(repo, '第*_*/*.md'))):
    m2 = re.search(r'(\d+)_(.+?)\.md', os.path.basename(f2))
    if not m2: continue
    cn = int(m2.group(1))
    slug = m2.group(2)
    with open(f2) as fh:
        title = fh.readline().strip().lstrip('# ')
    part_map = [(range(1,5),'part1-overview'),(range(5,10),'part2-resources'),(range(10,22),'part3-permissions'),
                (range(22,51),'part4-scheduling'),(range(51,64),'part5-structure'),(range(64,68),'part6-design'),
                (range(68,80),'part7-arch'),(range(80,86),'part8-classic')]
    part_dir = next((d for rng,d in part_map if cn in rng), '')
    part_name = next((p for rng,p in [(range(1,5),'总起'),(range(5,10),'资源'),(range(10,22),'权限'),
        (range(22,51),'调度'),(range(51,64),'结构'),(range(64,68),'设计'),
        (range(68,80),'架构'),(range(80,86),'经典')] if cn in rng), '')
    graph_data['nodes'].append({
        'id': cn, 'label': f'第{cn}章', 'title': title, 'slug': slug,
        'part': part_name, 'partDir': part_dir,
    })
    with open(f2) as fh:
        for line in fh:
            if line.strip().startswith('#'): continue
            for m3 in re.finditer(r'第(\d+)章', line):
                tc = int(m3.group(1))
                if tc != cn and 1 <= tc <= 85:
                    all_edges.add((cn, tc))
for s, t in sorted(all_edges):
    graph_data['edges'].append({'source': s, 'target': t})

with open(os.path.join(docs, 'graph-data.json'), 'w') as f:
    json.dump(graph_data, f, ensure_ascii=False)
print(f'[GRAPH] 图谱数据: {len(graph_data[\"nodes\"])} 节点, {len(graph_data[\"edges\"])} 条边')

# 输出统计
total = 0
for root, dirs, files in os.walk(docs):
    for f in files:
        if f.endswith('.md'):
            total += 1
print(f'[OK] 网站源文件已生成: {docs}')
print(f'总数: {total} 个页面')
"
