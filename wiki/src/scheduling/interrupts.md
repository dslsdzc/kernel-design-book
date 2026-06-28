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

## 参考文献

- Bovet & Cesati, "Understanding the Linux Kernel", 3rd Ed., Ch.4 (O'Reilly, 2005)
- Corbet et al., "Linux Device Drivers", 3rd Ed., Ch.10 (O'Reilly, 2005)
- Klein et al., "seL4: Formal Verification of an OS Kernel", SOSP 2009
- Blackham et al., "Improving interrupt response time in a verifiable protected microkernel", EuroSys 2012
- Achermann et al., "Formalizing Memory Accesses and Interrupts", MARS 2017
- ARM GIC Architecture Specification (IHI 0069H.b)
- QNX Neutrino System Architecture Guide

> 对应书籍：第 30 章（调度视角）、第 71 章（硬件架构视角）
