# 同步

同步防止多个执行流并发访问共享数据时的数据竞争。

## 系统对比

| 方面 | 常规 | Linux | seL4 | HIC | QNX | RTEMS | FreeRTOS |
|------|------|-------|------|-----|-----|-------|---------|
| 基本原语 | 互斥锁 | mutex/spinlock/rwsem | IPC (Send/Recv) | 无锁环形缓冲区 + Core-0 串行化 | mutex/semaphore | semaphore/event | mutex/semaphore |
| 内核锁 | 自旋锁 | spinlock_t | 无锁（隐式串行化） | Core-0 关中断无锁 | 自适应自旋 | 关中断 | 关调度 |
| RCU | 可选 | 主线 RCU | 不适用 | 不适用 | 不适用 | 不适用 | 不适用 |
| 死锁预防 | 锁排序 | lockdep 验证 | IPC 不会死锁 | 无锁设计 | 优先级继承 | 优先级继承 | 锁排序 |

## Linux 自旋锁实现

```c
// include/linux/spinlock.h
typedef struct spinlock {
    union {
        struct raw_spinlock rlock;
    };
} spinlock_t;

// arch/x86/include/asm/spinlock.h — x86 自旋锁
static __always_inline void spin_lock(spinlock_t *lock) {
    // x86 使用 LOCK CMPXCHG 实现
    asm volatile("1: lock; cmpxchg %1, %0\n\t"
                 "jz 2f\n\t"
                 "rep; nop\n\t"
                 "test %0, %0\n\t"
                 "jnz 1b\n\t"
                 "2:"
                 : "+m" (lock->rlock.lock), "+a" (0)
                 : "r" (1)
                 : "memory");
}
```

## Linux RCU 实现

RCU（Read-Copy-Update）在读多写少场景中将同步开销从读者转移到写者：

```c
// 读侧：几乎零开销
rcu_read_lock();          // 标记读临界区开始
ptr = rcu_dereference(p); // 读取指针
rcu_read_unlock();        // 标记读临界区结束

// 写侧：复制、更新、等待宽限期
new_ptr = kmalloc(...);
*new_ptr = *ptr;          // 复制数据
rcu_assign_pointer(p, new_ptr); // 原子替换指针
synchronize_rcu();        // 等待所有读者完成
kfree(ptr);               // 释放旧数据
```

## HIC 无锁设计

```c
// src/Core-0/scheduler.c — Core-0 运行在单核模式，禁用中断保证原子性
// Privileged-1 层服务之间通过无锁环形缓冲区通信

// 无锁环形缓冲区：仅使用内存屏障和原子操作
struct lockless_ring {
    volatile u32 head;
    volatile u32 tail;
    u8 data[RING_SIZE];
};

bool ring_push(struct lockless_ring *ring, u8 *data, u32 len) {
    u32 next = (ring->head + 1) % RING_SIZE;
    if (next == ring->tail) return false;  // 满
    memcpy(&ring->data[ring->head], data, len);
    atomic_store(&ring->head, next);        // 原子更新头指针
    return true;
}

bool ring_pop(struct lockless_ring *ring, u8 *data, u32 *len) {
    if (ring->tail == ring->head) return false;  // 空
    memcpy(data, &ring->data[ring->tail], *len);
    atomic_store(&ring->tail, (ring->tail + 1) % RING_SIZE);
    return true;
}
```

## 参考文献

- Linux kernel source: `kernel/locking/spinlock.c`, `kernel/rcu/`
- "Understanding the Linux Kernel", 3rd Ed., Ch.5 (Kernel Synchronization)
- Herlihy & Shavit, "The Art of Multiprocessor Programming"
- seL4 Manual, §3.2 IPC

> 对应书籍：第 33 章
