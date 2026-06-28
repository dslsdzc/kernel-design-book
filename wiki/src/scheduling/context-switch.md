# 上下文切换

上下文切换是调度器的核心工作：保存当前执行流的寄存器状态，恢复下一个执行流的寄存器状态。

## x86-64 切换实现

```asm
// arch/x86/entry/entry_64.S — __switch_to_asm
SYM_FUNC_START(__switch_to_asm)
    pushf
    pushq   %rbp
    movq    %rsp, TASK_threadsp(%rdi)   // prev->thread.sp = RSP
    movq    TASK_threadsp(%rsi), %rsp   // RSP = next->thread.sp（栈已切换）
    movq    $1f, TASK_threadip(%rdi)    // prev->thread.ip = 恢复点
    pushq   TASK_threadip(%rsi)         // next 的恢复点入栈
    jmp     __switch_to                  // 尾调用 C 函数
1:  popq    %rbp
    popf
    ret
SYM_FUNC_END(__switch_to_asm)
```

## C 函数 __switch_to

```c
// arch/x86/kernel/process_64.c
__attribute__((this_cpu))
struct task_struct *__switch_to(struct task_struct *prev_p,
                                 struct task_struct *next_p) {
    struct tss_struct *tss = &per_cpu(cpu_tss_rw, cpu);

    // 1. 切换 TSS 中的内核栈指针（为系统调用准备）
    tss->x86_tss.sp0 = task_top_of_stack(next_p);

    // 2. 切换 FPU 状态
    switch_fpu_prepare(prev_p, next_p, cpu);

    // 3. 切换 FS/GS（用户态 TLS）
    if (next->fs)  wrmsrl(MSR_FS_BASE, next->fs);
    if (next->gs)  load_gs_index(next->gsindex);

    return prev_p;
}
```

## TLB 切换

```c
// arch/x86/mm/tlb.c — address_space 切换
void switch_mm_irqs_off(struct mm_struct *prev, struct mm_struct *next,
                        struct task_struct *tsk) {
    if (prev != next) {
        // 写入 CR3 = 切换页表 = 刷新 TLB
        load_new_mm_cr3(next->pgd, TLB_FLUSH_ALL, false);
        this_cpu_write(cpu_tlbstate.loaded_mm, next);
    }
}
```

## 系统对比

| 方面 | 常规 | Linux | seL4 | HIC |
|------|------|-------|------|-----|
| 保存内容 | 寄存器 + 页表 | asm: 寄存器; C: FPU/TLS/CR3 | 同 Linux（更少） | 寄存器 + 能力 ID |
| 切换代价 | 上下文相关 | ~20-100 条指令 | ~50 条 | 能力查表 |
| 页表切换 | CR3 写入 | CR3 + TLB 刷新 | 无（单地址空间） | 无需（同一特权级） |

## 参考文献

- Linux kernel source: `arch/x86/entry/entry_64.S`, `arch/x86/kernel/process_64.c`
- "Understanding the Linux Kernel", 3rd Ed., Ch.10 (Context Switch)

> 对应书籍：第 25 章、第 72 章
