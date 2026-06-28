# 中断

中断是硬件向 CPU 发出异步请求的唯一通道——设备在任意时刻打断当前执行流，强制跳转到预设的中断处理程序。

## 核心特征

- **异步性**：中断时机与当前执行的指令无直接关系
- **优先级**：中断控制器仲裁多个中断源的紧急程度
- **可屏蔽性**：CPU 可暂时关闭中断

## 中断处理模型对比

### 上半部 / 下半部分离

| 系统 | 上半部 | 下半部 | 下半部可睡眠 | 特点 |
|------|--------|--------|-------------|------|
| **常规** | 关中断，快速保存上下文 | 开中断执行剩余处理 | 通常否 | 中断延迟与吞吐量的基本权衡 |
| **Linux** | 请求 `irq_disabled()` 中运行 | **Softirq/Tasklet/WorkQueue** 三级 | WorkQueue 可睡眠 | `Threaded IRQ` 将中断线程化（PREEMPT_RT） |
| **seL4** | 内核捕获，转换为 **IPC 通知** | 用户态驱动线程处理 | 是 | 中断即 IPC，全程能力验证 |
| **HIC** | **入口页 bt 自检** → `jmp` 业务页 | 业务逻辑直接在服务域执行 | 否 | 静态路由表，无内核数据路径 |
| **QNX** | 内核分发 **pulse 消息** 给驱动线程 | 用户态驱动处理 | 是 | 中断处理线程可被实时任务抢占 |
| **MINIX 3** | 内核捕获，转发 IPC 到驱动 | 用户态驱动服务处理 | 是 | 每中断至少 2 次上下文切换 |
| **CHERI** | 硬件能力保护中断向量表 | 标准上半部/下半部 | 否 | 能力保证中断向量表不可篡改 |

### 中断延迟

| 系统 | 典型延迟 | 最坏情况 | 可证明上界 |
|------|---------|---------|-----------|
| **常规** | 微秒级 | 依赖实现 | 通常无 |
| **Linux** | 1-5μs (PREEMPT_RT) | 100μs+ | 无（关中断临界区不可预测） |
| **seL4** | 200-500ns (IPC 路径) | 可分析 | WCET 分析可行 |
| **HIC** | 0.5-1μs（设计目标） | 静态路由表保证 | 硬件路由表查询时间确定 |
| **QNX** | 5-15μs | 确定上界 | 微内核极小，WCET 可分析 |
| **MINIX 3** | 10-50μs | 多 IPC 跳转叠加 | 难（多服务路径） |
| **CHERI** | 1-5μs（同 Linux） | 同 Linux | 能力检查增加少量开销 |

## 中断控制器的架构差异

| | x86 APIC | ARM GICv3/v4 | RISC-V CLINT+PLIC | RISC-V AIA |
|------|----------|-------------|-------------------|------------|
| 核本地中断 | Local APIC | PPI | CLINT (timer+sw) | IMSIC |
| 设备中断 | I/O APIC | SPI | PLIC | APLIC+IMSIC |
| MSI 支持 | 原生 | 无（GICv3 支持 LPI） | 无 | 原生 |
| 虚拟化 | VMX + APICv | GICv2m/vITS | 无 | 原生 IMSIC 注入 |

## 中断处理程序实现示例

### x86 中断入口（汇编）

```asm
# x86-64 中断入口模板 (arch/x86/entry_64.S)
.macro interrupt_stub num
    .globl interrupt_\num
interrupt_\num:
    pushq   $\num           # 中断号
    jmp     common_interrupt
.endm

common_interrupt:
    # 保存所有通用寄存器
    pushq   %r15
    pushq   %r14
    pushq   %r13
    pushq   %r12
    pushq   %r11
    pushq   %r10
    pushq   %r9
    pushq   %r8
    pushq   %rax
    pushq   %rcx
    pushq   %rdx
    pushq   %rbx
    pushq   %rsi
    pushq   %rdi
    mov     %rsp, %rdi      # 参数1: pt_regs
    call    do_IRQ          # C 处理函数
    # 恢复寄存器后 iretq
    popq    %rdi
    popq    %rsi
    ...
    iretq
```

### 中断处理函数注册（C）

```c
// Linux 风格中断处理注册
struct irqaction {
    irqreturn_t (*handler)(int, void *);
    unsigned long flags;
    const char *name;
    void *dev_id;
    struct irqaction *next;
    int irq;
};

int request_irq(unsigned int irq, irq_handler_t handler,
                unsigned long flags, const char *name, void *dev) {
    struct irqaction *action = kmalloc(sizeof(*action), GFP_KERNEL);
    action->handler = handler;
    action->flags = flags;
    action->name = name;
    action->dev_id = dev;
    action->next = NULL;
    action->irq = irq;

    // 将 action 挂入 irq_desc[irq] 的 action 链表
    struct irq_desc *desc = irq_to_desc(irq);
    desc->action = action;

    // 启用该中断
    unmask_irq(irq);
    return 0;
}

// 一个典型的中断处理函数
static irqreturn_t my_interrupt_handler(int irq, void *dev_id) {
    struct my_device *dev = (struct my_device *)dev_id;

    // 读取设备状态寄存器，确认是本设备中断
    uint32_t status = readl(dev->regs + REG_STATUS);
    if (!(status & STATUS_IRQ_PENDING))
        return IRQ_NONE;

    // 清除中断标志
    writel(status | STATUS_IRQ_CLEAR, dev->regs + REG_STATUS);

    // 从设备 FIFO 读取数据
    dev->rx_data = readl(dev->regs + REG_RX_FIFO);

    // 调度下半部处理数据（可调度 tasklet/workqueue）
    tasklet_schedule(&dev->tasklet);

    return IRQ_HANDLED;
}
```

### RISC-V 中断入口（汇编）

```asm
# RISC-V 中断入口 (M-mode)
.section .text.interrupt
.globl trap_vector
trap_vector:
    # 保存上下文
    csrrw   sp, mscratch, sp    # 切换栈
    addi    sp, sp, -32*REGBYTES
    STORE   x1, 1*REGBYTES(sp)
    STORE   x2, 2*REGBYTES(sp)
    # ... 保存所有寄存器

    # 读取中断原因
    csrr    t0, mcause
    csrr    t1, mtval

    # 判断是中断还是异常（mcause 最高位）
    bgez    t0, handle_exception

    # 中断处理
    andi    t0, t0, 0xFF       # 取中断号
    slli    t0, t0, 3          # 每项 8 字节
    la      t1, interrupt_table
    add     t1, t1, t0
    ld      t2, 0(t1)          # 加载处理函数地址
    jalr    t2                 # 调用

    # 恢复上下文
    LOAD    x1, 1*REGBYTES(sp)
    # ...
    csrrw   sp, mscratch, sp
    mret
```

### QNX 中断注册

```c
// QNX Neutrino 中断处理（用户态驱动）
const struct sigevent *my_isr(void *area, int id) {
    struct my_device *dev = (struct my_device *)area;

    dev->counter++;
    // 处理设备寄存器
    uint32_t st = in32(dev->base + REG_STATUS);
    out32(dev->base + REG_ACK, st);

    // 发送 pulse 通知驱动线程
    return &dev->pulse;  // 触发 IPC 消息
}

// 驱动线程中注册
int main() {
    struct my_device dev;
    dev.pulse = SIGEV_PULSE_INIT(&dev.coid, SIGEV_PULSE_PRIO,
                                  MY_DEV_PULSE, &dev);

    int id = InterruptAttach(IRQ_DEVICE, my_isr, &dev,
                             sizeof(dev), _NTO_INTR_FLAGS_TRK_MSK);
    // my_isr 运行在内核态，dev 运行在用户态
    // 中断通过脉冲消息传递给驱动线程
}
```

## 参考文献

- Bovet & Cesati, "Understanding the Linux Kernel", 3rd Ed., Ch.4 (O'Reilly, 2005)
- Corbet et al., "Linux Device Drivers", 3rd Ed., Ch.10 (O'Reilly, 2005)
- Klein et al., "seL4: Formal Verification of an OS Kernel", SOSP 2009
- Blackham et al., "Improving interrupt response time in a verifiable protected microkernel", EuroSys 2012
- Achermann et al., "Formalizing Memory Accesses and Interrupts", MARS 2017
- ARM GIC Architecture Specification (IHI 0069H.b)
- QNX Neutrino System Architecture Guide

> 对应书籍：第 30 章（调度视角）、第 71 章（硬件架构视角）
