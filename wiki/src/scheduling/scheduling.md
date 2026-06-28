# 调度模型

调度回答三个根本问题：**谁**（选哪个任务）、**什么时候**（何时做决策）、**用多久**（时间片多长）。

## 系统对比

| 方面 | 常规 | Linux CFS | Linux EEVDF | seL4 | HIC | QNX | MINIX 3 |
|------|------|-----------|-------------|------|-----|-----|---------|
| 调度对象 | 线程/进程 | `sched_entity` | `sched_entity` | TCB（线程） | 逻辑核心 | 线程 | 进程 |
| 优先级模型 | 固定/动态 | nice 值→权重 | 权重+时限 | 0-255 静态 | 能力配额 | 256 级 | 32 级 |
| 选择策略 | 时间片轮转 | vruntime 最小 | 最早截止+eligibility | 最高优先级 | 配额/独占 | 优先级+APS | 优先级 |
| 时间片 | 固定 | 动态（sched_latency） | 动态+deadline | 预算/周期 | 配额 | 可配 | 100ms |
| 负载均衡 | 无/简单 | 调度域层级 | 调度域层级 | 无（单核） | 逻辑核心迁移 | 分区绑定 | 无 |
| 实时性 | 无保证 | CFS尽力而为 | EEVDF有界延迟 | 硬实时（可证明） | 配额保证硬实时 | 硬实时（APS） | 无 |

## Linux CFS 调度器实现

### 核心数据结构

```c
// include/linux/sched.h
struct task_struct {
    // ...
    struct sched_entity   se;          // 调度实体（嵌入 task_struct）
    unsigned int          policy;      // SCHED_NORMAL / SCHED_RR / ...
    int                   prio;        // 动态优先级
    int                   static_prio; // 静态优先级（nice 映射）
    struct sched_class    *sched_class; // 指向 fair_sched_class
};

// kernel/sched/sched.h
struct sched_entity {
    struct load_weight      load;           // 权重（由 nice 值决定）
    struct rb_node          run_node;       // 红黑树节点
    unsigned int            on_rq;          // 是否在就绪队列
    u64                     vruntime;       // 虚拟运行时间（排序键）
    u64                     sum_exec_runtime; // 累计实际运行时间
};

struct cfs_rq {
    struct load_weight      load;
    unsigned int            nr_running;
    u64                     min_vruntime;
    struct rb_root_cached   tasks_timeline;  // 红黑树根（缓存最左节点）
    struct sched_entity    *curr;            // 当前运行实体
};
```

### 权重表

nice 值 (-20 到 19) 映射为权重，相邻级差 ~1.25 倍：

```c
// kernel/sched/sched.h
static const int prio_to_weight[40] = {
 /* -20 */ 88761, 71755, 56483, 46273, 36291,
 /* -15 */ 29154, 23254, 18705, 14949, 11916,
 /* -10 */  9548,  7620,  6100,  4904,  3906,
 /*  -5 */  3121,  2501,  1991,  1586,  1277,
 /*   0 */  1024,   820,   655,   526,   423,
 /*   5 */   335,   272,   215,   172,   137,
 /*  10 */   110,    87,    70,    56,    45,
 /*  15 */    36,    29,    23,    18,    15,
};
```

### vruntime 更新

```c
// kernel/sched/fair.c
static void update_curr(struct cfs_rq *cfs_rq) {
    struct sched_entity *curr = cfs_rq->curr;
    u64 now = rq_clock_task(rq_of(cfs_rq));
    u64 delta_exec = now - curr->exec_start;

    curr->exec_start = now;
    curr->sum_exec_runtime += delta_exec;

    // vruntime 增量 = 实际执行时间 × (基准权重 / 任务权重)
    curr->vruntime += calc_delta_fair(delta_exec, curr);

    update_min_vruntime(cfs_rq);
}

// 权重修正
static inline unsigned long
calc_delta_fair(unsigned long delta, struct sched_entity *se) {
    if (unlikely(se->load.weight != NICE_0_LOAD))
        delta = calc_delta_mine(delta, NICE_0_LOAD, &se->load);
    return delta;
}
```

### 选择下一个任务

```c
// kernel/sched/fair.c
static struct sched_entity *
pick_next_entity(struct cfs_rq *cfs_rq, struct sched_entity *curr) {
    // 取红黑树最左节点（vruntime 最小）
    struct rb_node *left = rb_first_cached(&cfs_rq->tasks_timeline);
    struct sched_entity *se = rb_entry(left, struct sched_entity, run_node);

    // EEVDF 新增：检查 eligibility
    if (curr && se && !entity_eligible(cfs_rq, se)) {
        se = pick_eevdf(cfs_rq);  // 找到第一个 eligible 的实体
    }

    return se;
}
```

## seL4 两级调度

```c
// 域调度（静态配置）
struct sched_domain {
    int domain_id;
    uint32_t schedule_table[256];  // 固定调度表
    int length;
};

// 域内优先级调度
thread_t *schedule(void) {
    int current_domain = get_current_domain();
    thread_t *thread = NULL;
    int highest_prio = 256;

    // 遍历当前域内的所有可运行线程
    for (int i = 0; i < num_threads; i++) {
        thread_t *t = &threads[i];
        if (t->domain != current_domain) continue;
        if (!t->runnable) continue;
        if (t->priority < highest_prio) {
            highest_prio = t->priority;
            thread = t;
        }
    }
    return thread;
}
```

## HIC 调度：逻辑核心配额

```
Privileged-1 层：硬性分配逻辑核心 + 时间配额
  → Core-0 保证服务在周期内获得确定 CPU 份额

Application-3 层：资源充足→独占核心，紧张→轮转退化
  → 独占时零切换开销，轮转时公平分配
```

## 参考文献

- Linux kernel source: `kernel/sched/fair.c`, `kernel/sched/sched.h`
- Linux kernel source: `kernel/sched/eevdf.c` (6.6+)
- "Understanding the Linux Kernel", 3rd Ed., Ch.7 (Scheduling)
- seL4 Manual, §3.1 Scheduling
- QNX Neutrino System Architecture, §4.3 Adaptive Partitioning
- Liedtke, "Toward Real Microkernels", CACM 1996
- "Improving interrupt response time in a verifiable protected microkernel", EuroSys 2012

> 对应书籍：第 22-29 章
