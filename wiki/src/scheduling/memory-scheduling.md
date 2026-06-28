# 内存调度

内存调度决定数据在物理内存中的位置和流动——哪些数据保留在内存中、哪些换出到磁盘、何时换出。

## 页面回收：LRU 与 MGLRU

### 传统 LRU

```c
// mm/vmscan.c — 传统 LRU 回收
// 维护 active/inactive 两个链表
// 扫描 inactive 链表，找到可回收页

// 简化的活跃/非活跃列表切换
void lru_cache_add_active(struct page *page) {
    // 新页面先加入 active 链表
    list_add(&page->lru, &zone->lru[LRU_ACTIVE_ANON]);
}
```

### Multi-Gen LRU (Linux 6.1+)

```c
// mm/vmscan.c — MGLRU（多代 LRU）
// 将页面分为多个世代，仅扫描最老世代
// 配置：CONFIG_LRU_GEN

struct lru_gen_folio {
    unsigned long  nr_pages[MAX_NR_GENS][ANON_AND_FILE][MAX_NR_ZONES];
    struct list_head folios[MAX_NR_GENS][ANON_AND_FILE][MAX_NR_ZONES];
};

// 访问检测：扫描页表访问位，将活跃页面提升到新世代
static void lru_gen_age_node(struct pglist_data *pgdat, struct scan_control *sc) {
    // 检查 PMD 和 PTE 的 young 位
    // 提升访问过的页面到最新世代
    inc_min_seq(pgdat);  // 淘汰最老世代
}

// 回收：从最老世代中选择页面
static unsigned long scan_folios(struct lruvec *lruvec, struct scan_control *sc) {
    // 从 min_seq（最老世代）开始扫描
    int gen = lruvec->mm_state.min_seq[type];
    list_for_each_entry(folio, &lruvec->lrugen.folios[gen][type][zone], lru) {
        if (folio_referenced(folio)) {
            // 被引用的页面提升到新世代
            folio_inc_gen(lruvec, folio, true);
        } else {
            // 未引用的页面标记为可回收
            isolate_folio(folio);
        }
    }
}
```

## 系统对比

| 方面 | 常规 | Linux (MGLRU) | Linux (传统 LRU) | seL4 | HIC |
|------|------|---------------|-----------------|------|-----|
| 回收策略 | LRU | 多代 LRU | 双链 LRU | 无分页 | 能力配额 |
| 扫描方式 | 全部 | 仅最老世代 | active/inactive | 不适用 | 不适用 |
| NUMA 感知 | 可选 | 支持 | 支持 | 不适用 | 逻辑核心迁移 |
| 实时保证 | 无 | 无 | 无 | 锁内存 | 特权能力配额 |

## 参考文献

- Linux kernel source: `mm/vmscan.c`, `mm/mlock.c`
- "MGLRU: Multi-Generational LRU", Linux Foundation
- "Understanding the Linux Kernel", 3rd Ed., Ch.15 (Memory Management)

> 对应书籍：第 32 章
