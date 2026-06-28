# 死锁

当多个执行流各自持有对方需要的资源，同时等待对方释放时，它们会永久阻塞。这就是死锁。

## 四个必要条件 (Coffman 1971)

```
1. 互斥（Mutual Exclusion）   — 资源一次只能被一个执行流使用
2. 持有并等待（Hold & Wait）  — 执行流持有资源的同时等待其他资源
3. 不可剥夺（No Preemption）  — 资源只能由持有者主动释放
4. 循环等待（Circular Wait）  — 存在等待环，A等B、B等C、C等A
```

四个条件必须同时满足，死锁才会发生。破坏任意一个即可预防死锁。

## 系统对比

| 方面 | 常规 | Linux | seL4 | HIC | QNX | RTEMS |
|------|------|-------|------|-----|-----|-------|
| 预防策略 | 锁排序 | lockdep 验证 + 锁排序 | 同步 IPC 无环 | 无锁设计消除锁 | 优先级继承 | 优先级天花板 |
| 检测方法 | 资源分配图 | lockdep 动态检测 | 形式化不变量 | 不适用（无锁） | 超时监控 | 超时监控 |
| 恢复策略 | 终止线程/剥夺资源 | Oops/Panic | 能力撤销 | Core-0 能力回收 | 重启问题线程 | 重启任务 |
| 鸵鸟算法 | 忽略 | 某些场景默认 | 不适用 | 不适用 | 不适用 | 不适用 |

## Linux lockdep 实现

lockdep 在内核运行时动态追踪锁获取顺序，检测潜在死锁：

```c
// kernel/locking/lockdep.c
// lockdep 是类级的（class-based），不是实例级的
// 相同类型的所有锁归为同一个锁类

void lock_acquire(struct lockdep_map *lock, unsigned int subclass,
                  int trylock, int read, int check, unsigned long ip) {
    struct task_struct *curr = current;
    struct held_lock *hlock;

    if (unlikely(!debug_locks)) return;

    // 1. 在 task_struct 中分配一个 held_lock 槽位
    hlock = &curr->held_locks[curr->lockdep_depth++];

    // 2. 记录当前的锁依赖
    //    → 构建 <prev_locks> → <current_lock> 的依赖边

    // 3. 检查新依赖是否形成环
    if (check && !check_noncircular(hlock, lock->class_cache))
        goto bad;
}

// 环检测：深度优先搜索锁依赖图
static int check_noncircular(struct held_lock *src, struct lock_class *target) {
    struct lock_list *entry;
    int depth = 0;

    // 从 src 出发，BFS/DFS 遍历锁依赖图
    list_for_each_entry(entry, &src->class->locks_after, entry) {
        if (entry->class == target)
            return 0;  // 发现环 → 报告死锁

        // 递归检测
        if (!check_noncircular(entry, target))
            return 0;
    }
    return 1;  // 无环
}
```

### 锁类与依赖图

lockdep 将锁按类组织（`lock_class`），每个类持有 `locks_before` 和 `locks_after` 两个链表记录依赖关系。当检测到环时，输出如下信息：

```
======================================================
[ INFO: possible circular locking dependency detected ]
======================================================
CPU#0's locks:
  &s->s_umount → &mm->mmap_lock (依赖链)
CPU#1's locks:
  &mm->mmap_lock → &s->s_umount (反向依赖)
```

## HIC 无锁消除死锁

HIC 的核心路径不使用传统锁机制，从根本上消除了锁排序死锁：

```c
// Core-0 单核执行，禁用中断保证原子性
// 能力表更新由 Core-0 串⾏化执行
// Privileged-1 服务间使用无锁环形缓冲区通信
// → 不接受锁，就没有锁的死锁

// 但能力系统的派生树可能形成循环依赖：
// A 持有能力 C1 等待 C2 → B 持有 C2 等待 C1
// → Core-0 通过能力撤销打破循环
```

## 参考文献

- Coffman, Elphick & Shoshani, "System Deadlocks", ACM Computing Surveys, 1971
- Linux kernel source: `kernel/locking/lockdep.c`
- "Understanding the Linux Kernel", 3rd Ed., Ch.5 (Locking)
- seL4 MCS Extensions, seL4 Foundation

> 对应书籍：第 34 章
