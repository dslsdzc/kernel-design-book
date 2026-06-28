import { useEffect, useRef } from 'react';
import { Network } from 'vis-network';
import { DataSet } from 'vis-data';

const PART_COLORS: Record<string, string> = {
  '总起': '#dbeafe', '资源': '#dcfce7', '权限': '#fef3c7',
  '调度': '#fce7f3', '结构': '#e0e7ff', '设计': '#f3e8ff',
  '架构': '#ffedd5', '经典': '#d1fae5',
};

export default function ChapterGraph() {
  const containerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!containerRef.current) return;

    fetch('/kernel-design-book/graph-data.json')
      .then(r => r.json())
      .then(data => {
        const nodes = new DataSet(data.nodes.map((n: any) => ({
          id: n.id,
          label: n.label,
          title: n.title,
          group: n.part,
          color: { background: PART_COLORS[n.part] || '#f1f5f9', border: '#64748b' },
          font: { size: 11, face: 'sans-serif' },
          borderWidth: 1,
          size: 20,
        })));

        const edges = new DataSet(data.edges.map((e: any) => ({
          from: e.source,
          to: e.target,
          color: { color: '#94a3b8', hover: '#2563eb' },
          width: 1,
          smooth: { type: 'curvedCW', roundness: 0.15 },
        })));

        const container = containerRef.current!;
        const network = new Network(container, { nodes, edges }, {
          physics: {
            solver: 'forceAtlas2Based',
            forceAtlas2Based: { gravitationalConstant: -40, springLength: 120, springConstant: 0.005 },
            stabilization: { iterations: 200 },
          },
          interaction: {
            hover: true,
            tooltipDelay: 100,
            navigationButtons: true,
          },
          edges: { arrows: { to: { enabled: true, scaleFactor: 0.6 } } },
        });

        network.on('click', (params: any) => {
          if (params.nodes.length > 0) {
            const n = data.nodes.find((x: any) => x.id === params.nodes[0]);
            if (n) {
              window.location.href = `/kernel-design-book/${n.partDir}/${n.slug}`;
            }
          }
        });
      });
  }, []);

  return (
    <div style={{ background: '#f8fafc', borderRadius: 12, padding: 16 }}>
      <p style={{ margin: '0 0 12px', color: '#64748b', fontSize: 14 }}>
        节点 = 章节，连线 = 交叉引用。悬停查看详情，点击跳转。
      </p>
      <div ref={containerRef} style={{ width: '100%', height: '600px', border: '1px solid #e2e8f0', borderRadius: 8 }} />
    </div>
  );
}
