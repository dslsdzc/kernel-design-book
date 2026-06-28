# 模块化

模块化将系统划分为独立单元，每个单元封装一组功能，对外暴露定义良好的接口。

## Linux 可加载内核模块 (LKM)

### 模块定义

```c
// 一个典型内核模块
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>

static int __init mymodule_init(void) {
    printk(KERN_INFO "My module loaded\n");
    return 0;
}

static void __exit mymodule_exit(void) {
    printk(KERN_INFO "My module unloaded\n");
}

module_init(mymodule_init);
module_exit(mymodule_exit);
MODULE_LICENSE("GPL");
MODULE_AUTHOR("Author");
MODULE_VERSION("1.0");
```

### 模块加载流程 (init_module 系统调用)

```c
// kernel/module/main.c — load_module()
// 从 init_module() → load_module() 的完整流程：

// 1. ELF 解析：验证模块 ELF 头和版本兼容性
// 2. 内存分配：layout_and_allocate() 分配 text/data/rodata/bss
// 3. 签名验证：mod_verify_sig()（CONFIG_MODULE_SIG）
// 4. 符号解析：simplify_symbols() → find_symbol()

// 符号解析核心
struct kernel_symbol {
    unsigned long value;     // 符号地址
    const char *name;        // 符号名
    const char *namespace;   // 符号命名空间
};

static int simplify_symbols(struct module *mod, const struct load_info *info) {
    Elf_Sym *sym = info->symtab;
    // 遍历符号表，对每个未定义符号调用 find_symbol()
    for (i = 1; i < info->nsyms; i++) {
        switch (sym[i].st_shndx) {
        case SHN_UNDEF:
            // 查找内核导出的符号
            ksym = find_symbol(name, &owner, NULL, true, true);
            if (!ksym) return -ENOENT;
            // 填入解析的地址
            sym[i].st_value = ksym->value;
            break;
        }
    }
    return 0;
}

// 5. 重定位：apply_relocate_add() 修正代码中的地址
// 6. 模块初始化：执行 module_init() 函数
```

### 符号导出

```c
// 内核导出的符号可以被模块引用
// include/linux/export.h
#define EXPORT_SYMBOL(sym) \
    extern typeof(sym) sym; \
    __EXPORT_SYMBOL(sym, "")

EXPORT_SYMBOL(schedule);      // kernel/sched/core.c
EXPORT_SYMBOL(kmalloc);       // mm/slab.c
```

## 系统对比

| 方面 | 常规 | Linux | seL4 | HIC | SPIN |
|------|------|-------|------|-----|------|
| 模块边界 | 地址空间 | 内核同一地址空间 | IPC 隔离 | 能力表定义 | 语言安全边界 |
| 动态加载 | 支持 | init_module 系统调用 | 静态配置 | 能力派生 | 动态链接 |
| 隔离性 | 弱 | 弱（共享地址空间） | 强（用户态） | 强（MMU 沙箱） | 语言级安全 |
| 接口定义 | 函数表 | `file_operations` 等 | 能力 + IPC | 能力 | Modula-3 接口 |

## 参考文献

- Linux kernel source: `kernel/module/main.c`, `include/linux/module.h`
- "Understanding the Linux Kernel", 3rd Ed., Ch.15 (Modules)
- "SPIN: An Extensible Microkernel", SOSP 1995

> 对应书籍：第 53 章
