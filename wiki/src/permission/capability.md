# 能力模型

能力（Capability）是一种不可伪造的资源访问令牌。持有令牌即意味着有权访问，无需额外查表——类似于电影票：检票员只看票，不问你是谁。

## 系统对比

| 方面 | 常规 | Linux | seL4 | HIC | QNX | MINIX 3 | CHERI |
|------|------|-------|------|-----|-----|---------|-------|
| 能力载体 | 内核对象句柄 | `cap_effective` 位图 | CNode 槽位 | 64位 ID 表项 | `SIGEV_PULSE` + 权限掩码 | 能力掩码 + ACL 混合 | 硬件能力寄存器 |
| 存储位置 | 内核维护表 | `struct cred` 中 | 能力空间 (CSpace) | Core-0 全局能力表 | 进程凭证 | PM 权限表 | CPU 寄存器 + 指针标签 |
| 传递方式 | 系统调用 | fork/exec 继承 | Move/Copy/Mint | ID 归属变更 | IPC 消息 | IPC 转发 | 指令派生子集 |
| 撤销 | 查表删条目 | 位图清零 | 递归派生树撤销 | 原子表更新 | 进程终止 | 吊销 PM 权限 | 标签位复位 |
| 权限衰减 | 受限 | 本身已拆分 | Mint 操作 | 能力派生 | IPC 权限掩码 | 文件权限 | 单调递减保证 |

## Linux 能力系统实现

### 数据结构

```c
// include/linux/cred.h — 进程凭证
struct cred {
    kuid_t      uid;          // 实际用户ID
    kgid_t      gid;          // 实际组ID
    kuid_t      euid;         // 有效用户ID
    kgid_t      egid;         // 有效组ID
    kernel_cap_t    cap_effective;   // 有效能力集（检查用）
    kernel_cap_t    cap_permitted;   // 允许能力集（上限）
    kernel_cap_t    cap_inheritable; // 可继承能力集
    kernel_cap_t    cap_bset;        // 限制集（bounding set）
    // ...
};
```

能力集为位图，每位对应一个能力：
```c
// include/linux/capability.h
#define CAP_CHOWN            0
#define CAP_DAC_OVERRIDE     1
#define CAP_NET_ADMIN       12
#define CAP_SYS_ADMIN       21
#define CAP_NET_RAW         13
#define CAP_SYS_RAWIO       17
// 共约 40 个能力
```

### 能力检查路径

```c
// kernel/capability.c — 入口
bool ns_capable(struct user_namespace *ns, int cap)
{
    return ns_capable_common(ns, cap, CAP_OPT_NONE);
}

static bool ns_capable_common(struct user_namespace *ns, int cap, unsigned int opts)
{
    int capable = security_capable(current_cred(), ns, cap, opts);
    if (capable == 0) {
        current->flags |= PF_SUPERPRIV;
        return true;
    }
    return false;
}
```

### LSM 分派

```c
// security/security.c
int security_capable(const struct cred *cred,
                     struct user_namespace *ns,
                     int cap, unsigned int opts)
{
    return call_int_hook(capable, 0, cred, ns, cap, opts);
}
```

### 核心检查 (cap_capable)

```c
// security/commoncap.c
int cap_capable(const struct cred *cred, struct user_namespace *targ_ns,
                int cap, unsigned int opts)
{
    struct user_namespace *ns = targ_ns;

    for (;;) {
        /* 在当前命名空间中检查有效集 */
        if (ns == cred->user_ns)
            return cap_raised(cred->cap_effective, cap) ? 0 : -EPERM;

        /* 超出当前命名空间层次，无权限 */
        if (ns->level <= cred->user_ns->level)
            return -EPERM;

        /* 父命名空间的 owner 拥有全部能力 */
        if ((ns->parent == cred->user_ns) && uid_eq(ns->owner, cred->euid))
            return 0;

        /* 向上层命名空间追溯 */
        ns = ns->parent;
    }
}
```

## seL4 能力空间 (CSpace) 实现

### CNode 结构

seL4 中每个线程有一个能力空间（CSpace），由 CNode（能力节点）组成。每个 CNode 是一个能力槽数组：

```c
// src/object/cnode.c — 能力槽结构
struct cte {
    cap_t          cap;             // 能力内容（16字节）
    mdb_node_t     cteMDBNode;      // MDB 节点（派生树链接）
};
```

### 能力寻址：带守卫的页表

seL4 使用带守卫的页表（Guarded Page Table）进行能力寻址：

```
[guard bits][radix bits] → slot index
  ↑           ↑
  固定值      二级索引

一个 CNode 块包含:
  capCNodeGuard      — 守卫值
  capCNodeGuardSize  — 守卫长度（位）
  capCNodeRadix      — 地址位长度（决定槽数，2^radix）
  capCNodePtr        — CNode 物理地址
```

### 地址解析实现

```c
// 简化版地址解析
int resolveAddressBits(cap_t cnode_cap, word_t cptr,
                       word_t depth, cte_t **result) {
    word_t guard = capCNodeGuard(cnode_cap);
    word_t gsize = capCNodeGuardSize(cnode_cap);
    word_t radix = capCNodeRadix(cnode_cap);
    word_t level_bits = gsize + radix;

    // 匹配守卫位
    word_t cguard = (cptr >> (depth - gsize)) & MASK(gsize);
    if (cguard != guard) return -1;

    // 读取 radix 位作为槽索引
    word_t slot = (cptr >> (depth - level_bits)) & MASK(radix);
    cte_t *cte = CTE_PTR(capCNodePtr(cnode_cap), slot);

    *result = cte;
    return 0;
}
```

### 能力派生树 (CDT)

撤销跟踪通过 MDB 节点实现双向链表：

```c
typedef struct mdb_node {
    word_t mdbNext;        // 下一个兄弟节点
    word_t mdbPrev;        // 上一个兄弟节点
    word_t mdbRevocable;   // 是否可撤销
    // ...
} mdb_node_t;

// 递归撤销
void cteDelete(cte_t *cte) {
    // 递归撤销子能力
    mdb_node_t *child = mdbFirstChild(&cte->cteMDBNode);
    while (child) {
        cteDelete(CTE_OF(child));
        child = mdbFirstChild(&cte->cteMDBNode);
    }
    // 清空当前槽
    cte->cap = cap_null;
}
```

## HIC 能力系统

```c
// HIC 能力表条目
struct hic_cap_entry {
    uint64_t  cap_id;        // 64位能力ID
    uint64_t  owner_domain;  // 持有者域ID
    uint64_t  perms;         // 权限位图
    uint64_t  parent_id;     // 父能力ID（派生树）
    uint64_t  type;          // 能力类型
    bool      valid;         // 有效标志
};

// 能力验证（Core-0 路径）
int hic_cap_check(cap_id_t cap_id, domain_id_t caller,
                  perm_t required) {
    struct hic_cap_entry *entry = &cap_table[cap_id];
    if (!entry->valid)             return -1;  // 无效能力
    if (entry->owner_domain != caller) return -2; // 不属于调用者
    if ((entry->perms & required) != required) return -3; // 权限不足
    return 0;  // 验证通过
}
```

## 参考文献

- Bovet & Cesati, "Understanding the Linux Kernel", 3rd Ed., Ch.8 (User ID, capabilities)
- Linux kernel source: `kernel/capability.c`, `security/commoncap.c`
- Klein et al., "seL4: Formal Verification of an OS Kernel", SOSP 2009
- seL4 Manual, §2.2 Capability Addressing
- CHERI ISA Specification, University of Cambridge
- Watson et al., "CHERI: A Hardware-Software System for Memory Safety", 2019

> 对应书籍：第 11 章、第 14 章
