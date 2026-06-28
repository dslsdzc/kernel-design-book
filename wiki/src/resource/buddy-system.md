# 伙伴系统

伙伴系统是 Linux 的物理内存页分配器，基于 `mm/page_alloc.c` 实现。

## 核心算法

```c
// mm/page_alloc.c — 伙伴系统的核心
// 将物理页按 order（2^order 页）分组管理
// free_area[order] 管理对应大小的空闲块链表

struct free_area {
    struct list_head free_list[MIGRATE_TYPES];  // 每迁移类型一链
    unsigned long   nr_free;
};

struct zone {
    struct free_area  free_area[MAX_ORDER];     // MAX_ORDER=11
    // ...
};
```

### 分配路径

```c
// 分配入口
struct page *alloc_pages(gfp_t gfp_mask, unsigned int order) {
    return __alloc_pages(gfp_mask, order);
}

// __alloc_pages → __alloc_pages_internal → get_page_from_freelist
// → buffered_rmqueue → __rmqueue

// 核心分配：从 free_list 移除页面块
static struct page *__rmqueue_smallest(struct zone *zone, unsigned int order,
                                       int migratetype) {
    // 从 order 开始向上搜索空闲块
    for (int current_order = order; current_order < MAX_ORDER; current_order++) {
        struct free_area *area = &zone->free_area[current_order];
        if (list_empty(&area->free_list[migratetype]))
            continue;

        struct page *page = list_entry(area->free_list[migratetype].next,
                                       struct page, lru);
        list_del(&page->lru);     // 从空闲链移除
        area->nr_free--;
        expand(zone, page, order, current_order, migratetype);  // 分裂
        return page;
    }
    return NULL;
}
```

### 分裂（expand）

```c
static void expand(struct zone *zone, struct page *page,
                   int low, int high, int migratetype) {
    // 高 order 中找到的块，分裂为低 order 的伙伴
    while (high > low) {
        area--;
        high--;
        size >>= 1;
        // 将后半部分加入对应 order 的空闲链表
        list_add(&page[size].lru, &area->free_list[migratetype]);
        area->nr_free++;
    }
}
```

### 释放与合并

```c
void __free_pages(struct page *page, unsigned int order) {
    // 释放时尝试合并伙伴
    // 两个相邻的 order-N 块 → 一个 order-(N+1) 块
    unsigned long page_idx = page_to_pfn(page) & ((1 << MAX_ORDER) - 1);
    // 检查伙伴是否空闲且同 order
    // 若空闲则合并，继续向上检查
}
```

## 系统对比

| 方面 | Linux 伙伴系统 | seL4 | HIC |
|------|---------------|------|-----|
| 分配单位 | 2^order 页 | Untyped 区域 | 连续物理页能力 |
| 碎片管理 | 迁移类型 + 压缩 | 无（静态配置） | 无（能力配额） |
| 分配速度 | O(log n) | 用户态 Retype | O(1) 查表 |

## 参考文献

- Linux kernel source: `mm/page_alloc.c`
- "Understanding the Linux Kernel", 3rd Ed., Ch.15 (Page Allocator)
- Knowlton, "A Fast Storage Allocator", CACM 1965

> 对应书籍：第 32 章
