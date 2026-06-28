# 同步

同步防止多个执行流并发访问共享数据时的数据竞争。

## 系统对比

| 方面 | 常规 | Linux | seL4 | HIC | QNX | RTEMS | FreeRTOS |
|------|------|-------|------|-----|-----|-------|---------|
| 基本原语 | 互斥锁 | mutex/spinlock/rwsem | IPC (Send/Recv) | 无锁环形缓冲区 + Core-0 串⾏化 | mutex/semaphore | semaphore/event | mutex/semaphore |
| 内核锁 | 自旋锁 | qspinlock | 无锁（隐式串⾏化） | Core-0 关中断无锁 | 自适应自旋 | 关中断 | 关调度 |
| RCU | 可选 | 主线 RCU | 不适用 | 不适用 | 不适用 | 不适用 | 不适用 |

## Linux 自旋锁实现 (Queued Spinlock)

现代 Linux 使用 queued spinlock（qspinlock），优化多核争用场景：

```c
// arch/x86/include/asm/qspinlock.h
// 使用 atomic_try_cmpxchg() 尝试获取锁（编译为 lock cmpxchg）
#define __queued_spin_lock(lock) \
    do { \
        int __val; \
        while ((__val = atomic_read(&lock->val)) || \
               !atomic_try_cmpxchg(&lock->val, &__val, _Q_LOCKED_VAL)) \
            cpu_relax(); \
    } while (0)

// 生成的汇编：
//    mov    $0x1,%edx
//    mov    (%rbx),%eax      ; atomic_read
//    test   %eax,%eax
//    jne    loop             ; 锁已被持有，自旋
//    lock cmpxchg %edx,(%rbx) ; 尝试获取
//    jne    loop             ; 失败则重试
//    pause                    ; cpu_relax()
```

## Linux RCU 实现

读侧路径极快——只需递增嵌套计数：

```c
// kernel/rcu/tree.c — Preemptible RCU
void __rcu_read_lock(void) {
    current->rcu_read_lock_nesting++;
    barrier();
}

void __rcu_read_unlock(void) {
    struct task_struct *t = current;
    if (t->rcu_read_lock_nesting != 1) {
        --t->rcu_read_lock_nesting;
    } else {
        barrier();
        t->rcu_read_lock_nesting = INT_MIN;
        barrier();
        if (unlikely(READ_ONCE(t->rcu_read_unlock_special)))
            rcu_read_unlock_special(t);
        barrier();
        t->rcu_read_lock_nesting = 0;
    }
}

// 写者等待宽限期
// kernel/rcu/tree.c
void synchronize_rcu(void) {
    // 检查是否在 RCU 读侧临界区内
    RCU_LOCKDEP_WARN(lock_is_held(&rcu_lock_map), ...);
    if (rcu_blocking_is_gp()) return;  // 单核：立即返回
    if (rcu_gp_is_expedited())
        synchronize_rcu_expedited();   // 快速路径（IPI）
    else
        wait_rcu_gp(call_rcu);         // 正常路径
}
```

## HIC 无锁设计

HIC 核心路径无锁——Core-0 单核执行禁用中断保证原子性，Privileged-1 层服务间通过无锁环形缓冲区通信：

```c
// src/Core-0/scheduler.c — Core-0 单核串⾏化
// Core-0 运行在单核模式，禁用中断保证原子性
// 能力表更新由 Core-0 串⾏化执行，不需要锁

// src/Core-0/capability_core.c — Per-core slot 分区
// 每个核独占 CAP_SLOTS_PER_CORE 个槽位，无全局锁竞争
#define CAP_SLOTS_PER_CORE   256
u32 g_cap_next_free[CAP_MAX_CORES];

// 分配新能力：从 per-core 槽位分配器获取，无需锁
cap_id_t cap_alloc(domain_id_t domain) {
    u32 core = get_core_id();
    cap_id_t id = core * CAP_SLOTS_PER_CORE + g_cap_next_free[core]++;
    // ... 初始化能力表项
    return id;
}
```

## 参考文献

- Linux kernel source: `arch/x86/include/asm/qspinlock.h`, `kernel/rcu/tree.c`
- "Understanding the Linux Kernel", 3rd Ed., Ch.5
- McKenney, "Is Parallel Programming Hard?", 2025 Ed.
- Herlihy & Shavit, "The Art of Multiprocessor Programming"

> 对应书籍：第 33 章
