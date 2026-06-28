# 死锁

当多个执行流各自持有对方需要的资源，同时等待对方释放时，它们永久阻塞。这就是死锁。

## 四个必要条件 (Coffman 1971)

1. **互斥** — 资源一次只能被一个执行流使用
2. **持有并等待** — 执行流持有资源的同时等待其他资源
3. **不可剥夺** — 资源只能由持有者主动释放
4. **循环等待** — 存在等待环，A 等 B、B 等 C、C 等 A

四个条件同时满足，死锁才会发生。

## 系统对比

| 方面 | 常规 | Linux | seL4 | HIC | QNX | RTEMS |
|------|------|-------|------|-----|-----|-------|
| 预防 | 锁排序 | lockdep + 锁排序 | 同步 IPC 无环 | 无锁设计 | 优先级继承 | 优先级天花板 |
| 检测 | 资源分配图 | lockdep BFS 环检测 | 形式化不变量 | 不适用（无锁） | 超时 | 超时 |
| 恢复 | 终止线程 | Oops/Panic | 能力撤销 | Core-0 能力回收 | 重启任务 | 重启任务 |

## Linux lockdep 实现

lockdep 是内核运行时锁验证器，在锁获取时动态检测环：

```c
// kernel/locking/lockdep.c — 关键调用路径
// 添加新依赖前，检查是否形成环
check_prevs_add() → check_prev_add() →
    check_noncircular()    // 环检测（BFS 向前搜索）
    check_redundant()      // 冗余检查
    add_lock_to_list()     // 存储依赖

// check_noncircular — BFS 遍历锁依赖图
static enum bfs_result
check_noncircular(struct held_lock *src, struct held_lock *target,
                  struct lock_list **target_entry) {
    return __bfs_forwards(src, target, hlock_conflict, target_entry);
}

// hlock_conflict — 判断找到的环是否为真死锁
static inline bool hlock_conflict(struct lock_list *entry, void *data) {
    struct held_lock *hlock = (struct held_lock *)data;

    return hlock_class(hlock) == entry->class &&
           (hlock->read == 0 ||       // 写锁环 → 真死锁
            !entry->only_xr);          // 强依赖路径 → 真死锁
}
```

lockdep 将锁按**类**（lock class）组织，相同类型的所有锁共享一个类。依赖图中的每个节点是一个锁类，边表示获取顺序（`locks_before`/`locks_after`）。

检测到环时输出：
```
======================================================
[ INFO: possible circular locking dependency detected ]
======================================================
CPU#0 持有 &mm->mmap_lock 等待 &s->s_umount
CPU#1 持有 &s->s_umount 等待 &mm->mmap_lock
  → 环形成，可能死锁
```

## HIC 无锁消除死锁

HIC 核心路径无传统锁机制，从根本上消除锁排序死锁：

```c
// Core-0 单核执行禁用中断保证原子性（无锁争用）
// Privileged-1 层服务间无锁环形缓冲区通信
// 能力表由 Core-0 串⾏化更新（无并发写）

// 能力撤销是打破循环等待的主要手段：
// 当依赖形成环时，Core-0 撤销环中某个能力
// 撤销传播沿能力派生树递归 → 依赖链被切断
```

## 参考文献

- Coffman, Elphick & Shoshani, "System Deadlocks", ACM Computing Surveys, 1971
- Linux kernel source: `kernel/locking/lockdep.c`
- "Understanding the Linux Kernel", 3rd Ed., Ch.5
- McKenney, "Is Parallel Programming Hard?", 2025 Ed.

> 对应书籍：第 34 章
