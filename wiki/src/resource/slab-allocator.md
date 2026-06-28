# Slab 分配器

Slab 分配器用于管理小对象（task_struct、inode 等）的频繁分配释放，避免伙伴系统的碎片和开销。

## 核心结构

```c
// mm/slab.h — kmem_cache 数据结构
struct kmem_cache {
    unsigned int  object_size;     // 对象原始大小
    unsigned int  size;            // 对齐后大小
    unsigned int  align;           // 对齐
    unsigned long flags;           // SLAB_* 标志
    const char   *name;            // 缓存名称
    void (*ctor)(void *);          // 构造函数
    struct list_head list;         // slab_caches 全局链表
    struct kmem_cache_node **node;  // Per-NUMA-node 管理
};

// Per-NUMA-node 管理
struct kmem_cache_node {
    spinlock_t      list_lock;
    struct list_head slabs_partial;  // 部分使用
    struct list_head slabs_full;     // 全部使用
    struct list_head slabs_free;     // 完全空闲
    unsigned long   free_objects;
    unsigned int    free_limit;
};
```

## 创建与使用

```c
// 创建 slab 缓存
struct kmem_cache *task_struct_cachep = kmem_cache_create(
    "task_struct", sizeof(struct task_struct), 0,
    SLAB_PANIC, NULL);

// 分配对象
struct task_struct *p = kmem_cache_alloc(task_struct_cachep, GFP_KERNEL);

// 释放对象
kmem_cache_free(task_struct_cachep, p);
```

## 分配流程

```
kmem_cache_alloc(cachep, flags)
  → slab_alloc(cachep, flags, caller)
    → 查找空闲对象:
      1. 从 slabs_partial 取
      2. 从 slabs_free 取
      3. 从伙伴系统分配新 slab
    → 返回对象指针
```

## 参考文献

- Linux kernel source: `mm/slab_common.c`, `mm/slub.c`
- "Understanding the Linux Kernel", 3rd Ed., Ch.15 (Slab)
- Bonwick, "The Slab Allocator", USENIX 1994

> 对应书籍：第 32 章
