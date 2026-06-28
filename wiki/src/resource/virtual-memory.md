# 虚拟内存

虚拟内存通过地址转换将进程的虚拟地址映射到物理内存，每个进程以为自己独占整个地址空间。

## 地址转换比较

| 架构 | 页表基址 | 页表结构 | 页大小 | 页表级数 |
|------|---------|---------|--------|---------|
| x86 (32bit PAE) | CR3 | 三级页表（PDPT/PD/PT） | 4KB | 3 |
| x86-64 | CR3 | 四级页表（PML4/PDPT/PD/PT） | 4KB | 4 |
| x86-64 (5-level) | CR3 | 五级页表 | 4KB | 5 |
| ARMv8-A | TTBR0/1 | 三/四级（TCR 配置） | 4KB/16KB/64KB | 3-4 |
| RISC-V | satp | 三级（Sv39，39 位地址） | 4KB | 3 |

## Linux x86-64 页表遍历

```c
// arch/x86/include/asm/pgtable.h
// 四级页表：PML4 → PDPT → PD → PT → 4K 页

// CR3 指向 PML4 表
// 虚拟地址分解：
// | PML4(9) | PDPT(9) | PD(9) | PT(9) | OFFSET(12) | = 48 位

static pte_t *get_pte(struct mm_struct *mm, unsigned long addr) {
    pgd_t *pgd = pgd_offset(mm, addr);          // PML4 索引
    p4d_t *p4d = p4d_offset(pgd, addr);         // 4级
    pud_t *pud = pud_offset(p4d, addr);          // 3级
    pmd_t *pmd = pmd_offset(pud, addr);          // 2级
    pte_t *ptep = pte_offset_kernel(pmd, addr);  // 1级 (页表)
    return ptep;
}

// 缺页异常处理
// mm/memory.c
vm_fault_t handle_mm_fault(struct vm_area_struct *vma, unsigned long addr,
                            unsigned int flags, struct pt_regs *regs) {
    // 1. 查找 VMA（虚拟内存区域）
    // 2. 分配物理页
    // 3. 建立页表映射
    // 4. 返回用户态继续执行
}
```

## 系统对比

| 方面 | Linux | seL4 | HIC |
|------|-------|------|-----|
| 地址空间 | 每进程独立 | 线程级页表 | Core-0 + Privileged-1 共享 |
| 缺页处理 | `handle_mm_fault` | 无（预映射） | 简单（连续物理内存） |
| TLB 刷新 | CR3 + PCID | 刷新全部 | 无需（同特权级） |

## 参考文献

- Linux kernel source: `arch/x86/include/asm/pgtable.h`, `mm/memory.c`
- "Understanding the Linux Kernel", 3rd Ed., Ch.2 (Address Translation)
- Intel SDM Vol.3, Ch.4 (Paging)

> 对应书籍：第 70 章
