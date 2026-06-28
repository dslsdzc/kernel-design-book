# 可扩展性

可扩展性解决：如何在不修改内核核心代码的前提下添加新功能。

## eBPF 可扩展架构

eBPF 允许用户态将经过验证的字节码注入内核，在安全钩子点执行。

### eBPF 验证器

```c
// kernel/bpf/verifier.c — bpf_check()
// 两遍静态分析：
// 第一遍：DFS 检查程序为 DAG（无环）
// 第二遍：逐指令模拟执行，追踪寄存器状态

// 寄存器类型追踪：
// R0=return, R1-R5=args, R6-R9=callee-saved, R10=fixed frame pointer
enum bpf_reg_type {
    NOT_INIT, SCALAR_VALUE, PTR_TO_CTX,
    PTR_TO_MAP_VALUE, PTR_TO_MAP_VALUE_OR_NULL,
    PTR_TO_STACK, PTR_TO_SOCKET,
    PTR_TO_BTF_ID, // ...
};

struct bpf_reg_state {
    enum bpf_reg_type type;
    s64 min_value;    // 值范围下界
    s64 max_value;    // 值范围上界
    u64 umin_value;   // 无符号下界
    u64 umax_value;   // 无符号上界
    struct tnum var_off;  // 可能值的集合（tristate numbers）
};
```

### BPF 程序加载流程

```c
bpf() syscall
  → bpf_prog_load()
    → bpf_check()           // 验证器（安全性检查）
      → check_cfg()         // 循环检测
      → do_check()          // 逐指令模拟
        → check_mem_access() // 内存访问检查
        → check_func_arg()   // 辅助函数参数检查
    → bpf_prog_select_runtime()
      → bpf_int_jit_compile_head()  // JIT 编译
```

## 系统对比

| 方面 | 常规 | Linux | SPIN | seL4 | HIC |
|------|------|-------|------|-----|-----|
| 扩展点 | 系统调用 | eBPF / LKM | 语言级动态链接 | IPC + 能力 | 能力派生 |
| 安全检查 | 无 | eBPF 验证器 (DAG+类型) | Modula-3 类型安全 | 能力验证 | 能力验证 |
| 动态加载 | 模块 | init_module / bpf() | 动态调用绑定 | 静态配置 | 服务沙箱加载 |
| 隔离 | 地址空间 | 内核空间/用户空间 | 语言级隔离 | MMU 隔离 | MMU 沙箱 |

## 参考文献

- Linux kernel source: `kernel/bpf/verifier.c`, `kernel/bpf/syscall.c`
- "SPIN: An Extensible Microkernel", SOSP 1995
- "eBPF: A New Frontier in Networking and Security", ACM SIGCOMM 2021
- "The BSD Packet Filter: A New Architecture for User-level Packet Capture", USENIX 1993

> 对应书籍：第 62 章
