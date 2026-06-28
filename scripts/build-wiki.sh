#!/bin/bash
# 构建 Wiki + 自动生成系统聚合页 + SUMMARY
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WIKI_SRC="$REPO_DIR/wiki/src"
SYSTEMS_DIR="$WIKI_SRC/systems"
mkdir -p "$SYSTEMS_DIR"

python3 -c "
import os, re, glob

wiki = '$WIKI_SRC'
systems_dir = '$SYSTEMS_DIR'
system_names = ['seL4', 'Linux', 'HIC', 'QNX', 'MINIX', 'CHERI', 'L4']
pattern = re.compile(r'^##\s+(.*?(' + '|'.join(system_names) + r').*)', re.MULTILINE)

# ── 1. 扫描概念页 ──
concepts = {'permission': [], 'scheduling': [], 'structure': [], 'resource': []}
systems = {s: [] for s in system_names}

for page in sorted(glob.glob(os.path.join(wiki, '**', '*.md'), recursive=True)):
    rp = os.path.relpath(page, wiki)
    if '/systems/' in rp or rp in ('SUMMARY.md','CONTRIBUTING.md','index.md'): continue
    with open(page) as f: content = f.read()

    cat = rp.split('/')[0] if '/' in rp else ''
    base = os.path.splitext(os.path.basename(page))[0]
    if base == 'README': continue
    # 提取页面标题（第一行 H1）
    title = base.replace('-', ' ').title()
    for line in content.split('\n'):
        if line.startswith('# '):
            title = line[2:].strip()
            break
    if cat in concepts: concepts[cat].append(f'  - [{title}]({rp})')

    for m in pattern.finditer(content):
        heading = m.group(1)
        for s in system_names:
            if s in heading: systems[s].append(f'  - [{heading}]({rp})')

# ── 2. 生成系统页 ──
for sys, items in systems.items():
    with open(os.path.join(systems_dir, f'{sys}.md'), 'w') as f:
        f.write(f'# {sys}\n\n该页面自动聚合了各概念页中提及 {sys} 的内容。\n\n')
        if items: f.write('## 相关内容\n\n' + '\n'.join(items) + '\n')
        else: f.write('暂未收录相关内容。\n')

# ── 3. 生成 SUMMARY.md ──
summary = '''# 内核设计 Wiki

[关于此 Wiki](index.md)

---
'''
for cat, label in [('permission','权限模型'),('scheduling','调度模型'),('structure','结构模型'),('resource','资源模型')]:
    items = concepts.get(cat, [])
    summary += f'- [{label}]({cat}/README.md)\n'
    for i in items: summary += i + '\n'

summary += '\n---\n\n## 按系统浏览\n'
for s in system_names:
    summary += f'- [{s}](systems/{s}.md)\n'

summary += '\n---\n\n- [贡献指南](CONTRIBUTING.md)\n'

with open(os.path.join(wiki, 'SUMMARY.md'), 'w') as f:
    f.write(summary)

print(f'[OK] {len(system_names)} 系统页 + {sum(len(v) for v in concepts.values())} 概念页')
"
