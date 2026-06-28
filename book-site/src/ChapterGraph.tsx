import { useEffect, useRef } from 'react';
import { Network } from 'vis-network';
import { DataSet } from 'vis-data';

const PART_COLORS_LIGHT: Record<string, string> = {
  '总起': '#dbeafe', '资源': '#dcfce7', '权限': '#fef3c7',
  '调度': '#fce7f3', '结构': '#e0e7ff', '设计': '#f3e8ff',
  '架构': '#ffedd5', '经典': '#d1fae5',
};

const PART_COLORS_DARK: Record<string, string> = {
  '总起': '#1e3a5f', '资源': '#14532d', '权限': '#713f12',
  '调度': '#831843', '结构': '#312e81', '设计': '#4c1d95',
  '架构': '#7c2d12', '经典': '#064e3b',
};

function isDark() {
  return document.documentElement.classList.contains('dark');
}

export default function ChapterGraph() {
  const containerRef = useRef<HTMLDivElement>(null);
  const networkRef = useRef<Network | null>(null);

  useEffect(() => {
    if (!containerRef.current) return;
    const container = containerRef.current;

    fetch('/kernel-design-book/graph-data.json')
      .then(r => r.json())
      .then(data => {
        const dark = isDark();
        const colors = dark ? PART_COLORS_DARK : PART_COLORS_LIGHT;
        const bg = dark ? '#1e293b' : '#f8fafc';
        const borderColor = dark ? '#94a3b8' : '#64748b';
        const edgeColor = dark ? '#475569' : '#94a3b8';
        const edgeHover = dark ? '#60a5fa' : '#2563eb';
        const fontColor = dark ? '#e2e8f0' : '#1e293b';

        const nodes = new DataSet(data.nodes.map((n: any) => ({
          id: n.id, label: n.label, title: n.title, group: n.part,
          color: { background: colors[n.part] || bg, border: borderColor },
          font: { size: 11, color: fontColor },
          borderWidth: 1, size: 20,
        })));

        const edges = new DataSet(data.edges.map((e: any) => ({
          from: e.source, to: e.target,
          color: { color: edgeColor, hover: edgeHover },
          width: 1,
          smooth: { type: 'curvedCW', roundness: 0.15 },
        })));

        container.style.background = bg;
        networkRef.current = new Network(container, { nodes, edges }, {
          physics: {
            solver: 'forceAtlas2Based',
            forceAtlas2Based: { gravitationalConstant: -40, springLength: 120, springConstant: 0.005 },
            stabilization: { iterations: 200 },
          },
          interaction: { hover: true, tooltipDelay: 100, navigationButtons: true },
          edges: { arrows: { to: { enabled: true, scaleFactor: 0.6 } } },
        });

        networkRef.current.on('click', (params: any) => {
          if (params.nodes.length > 0) {
            const n = data.nodes.find((x: any) => x.id === params.nodes[0]);
            if (n) window.location.href = `/kernel-design-book/${n.partDir}/${n.slug}.html`;
          }
        });

        // 监听主题切换
        const observer = new MutationObserver(() => {
          const d = isDark();
          const c2 = d ? PART_COLORS_DARK : PART_COLORS_LIGHT;
          const bg2 = d ? '#1e293b' : '#f8fafc';
          container.style.background = bg2;
          data.nodes.forEach((n: any) => {
            nodes.update({ id: n.id, color: { background: c2[n.part] || bg2, border: d ? '#94a3b8' : '#64748b' } });
          });
          networkRef.current?.setOptions({
            edges: { color: { color: d ? '#475569' : '#94a3b8', hover: d ? '#60a5fa' : '#2563eb' } },
          });
        });
        observer.observe(document.documentElement, { attributes: true, attributeFilter: ['class'] });
      });
  }, []);

  return (
    <div style={{ borderRadius: 12, padding: 16 }}>
      <p style={{ margin: '0 0 12px', color: 'var(--rp-c-text-2)', fontSize: 14 }}>
        节点 = 章节，连线 = 交叉引用。悬停查看详情，点击跳转。
      </p>
      <div ref={containerRef} style={{ width: '100%', height: '600px', border: '1px solid var(--rp-c-border)', borderRadius: 8 }} />
    </div>
  );
}
