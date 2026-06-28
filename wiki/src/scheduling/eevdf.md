# EEVDF 调度器

EEVDF（Earliest Eligible Virtual Deadline First）自 Linux 6.6（2023年）起取代 CFS，成为默认调度器。

## 核心算法

EEVDF 在 CFS 的权重基础上增加了**时限**维度：

```
每个任务维护：
  - weight（权重，由 nice 决定）
  - slice（时间片长度）
  - virtual deadline（虚拟截止时间）
  - virtual runtime（虚拟运行时间）

选择规则：
  1. 只考虑 eligible（未超额）的任务
  2. 从 eligible 任务中选 deadline 最早的
```

### 关键实现

```c
// kernel/sched/fair.c — pick_eevdf()
// 增强红黑树，支持按 min_deadline 快速查找
struct sched_entity {
    struct load_weight  load;
    struct rb_node      run_node;
    u64                 vruntime;
    u64                 deadline;       // 截止时间
    u64                 min_deadline;   // 子树最小截止时间（增强属性）
};

static struct sched_entity *pick_eevdf(struct cfs_rq *cfs_rq) {
    struct rb_node *node = cfs_rq->tasks_timeline.rb_root.rb_node;
    struct sched_entity *best = NULL;

    while (node) {
        struct sched_entity *se = __node_2_se(node);

        if (!entity_eligible(cfs_rq, se)) {
            node = node->rb_left;
            continue;
        }

        if (!best || deadline_gt(deadline, best, se))
            best = se;

        // 利用 min_deadline 剪枝
        if (node->rb_left &&
            __node_2_se(node->rb_left)->min_deadline == se->min_deadline) {
            node = node->rb_left;
            continue;
        }
        node = node->rb_right;
    }
    return best;
}
```

## 对比

| 特性 | CFS | EEVDF |
|------|-----|-------|
| 排序键 | vruntime | eligibility + deadline |
| 数据结构 | 普通红黑树 | 增强红黑树（min_deadline）|
| 时间片 | 动态（sched_latency） | 基准时间片 + 相对 deadline |
| 延迟控制 | 隐式（通过权重） | 显式（通过 slice 参数） |
| 合并时间 | Linux 2.6.23 (2007) | Linux 6.6 (2023) |

## 参考文献

- Linux kernel source: `kernel/sched/fair.c` (pick_eevdf, entity_eligible)
- LWN: "An EEVDF CPU scheduler for Linux", 2023
- Stoica & Abdel-Wahab, "Earliest Eligible Virtual Deadline First", 1995

> 对应书籍：第 27 章
